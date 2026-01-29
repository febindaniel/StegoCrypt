
from PIL import Image, ImageOps
import io
import struct
import math

def get_bit(val, n):
    return (val >> n) & 1

def set_bit(val, n, bit):
    mask = 1 << n
    val &= ~mask
    if bit:
        val |= mask
    return val

def encode_image(image_path: str, secret_data: bytes, output_path: str) -> str:
    img = Image.open(image_path)
    img = ImageOps.exif_transpose(img)
    img = img.convert('RGB')
    width, height = img.size
    total_pixels = width * height
    
    # Header format:
    # 1 byte for bits_per_channel (uint8)
    # 4 bytes for data length (uint32)
    # Total header bits = 40. We ALWAYS encode header with 1 bit LSB for stability.
    header_bits_count = 8 + 32
    
    # Calculate bits needed for data
    data_bits_count = len(secret_data) * 8
    
    # Max capacity with 3 bits per channel (3 * 3 = 9 bits per pixel)
    # We can go up to 4 bits per channel, but quality degrades. 
    # Let's support 1, 2, 3, 4 bits per channel.
    
    # Available pixels for contents
    # We consume pixels for header first.
    # Header uses 1 bit per channel (3 bits per pixel).
    # Header needs ceil(40 / 3) pixels.
    pixels_for_header = math.ceil(header_bits_count / 3)
    pixels_available_for_data = total_pixels - pixels_for_header
    
    if pixels_available_for_data <= 0:
        raise ValueError("Image too small even for header.")

    bits_per_channel = 1
    found_capacity = False
    
    # Try 1, 2, 3, 4
    for bpc in range(1, 5):
        # bits per pixel = bpc * 3 (R, G, B)
        capacity_bits = pixels_available_for_data * bpc * 3
        if capacity_bits >= data_bits_count:
            bits_per_channel = bpc
            found_capacity = True
            break
            

    if not found_capacity:
        # Auto-resize (Scale up) logic
        # We need data_bits_count bits.
        # Max density is 4 bits per channel * 3 = 12 bits per pixel.
        needed_pixels = math.ceil(data_bits_count / 12) + pixels_for_header
        
        # Calculate new dimensions preserving aspect ratio
        current_ratio = width / height
        new_area = needed_pixels
        # area = w * h = (h * ratio) * h = h^2 * ratio
        # h = sqrt(area / ratio)
        new_height = int(math.sqrt(new_area / current_ratio))
        new_width = int(new_height * current_ratio)
        
        # Add a safety margin (10%)
        new_width = int(new_width * 1.1)
        new_height = int(new_height * 1.1)
        
        # Ensure it's at least the original size
        new_width = max(width, new_width)
        new_height = max(height, new_height)
        
        # Resize image using LANCZOS to maintain quality as much as possible, 
        # though steganography doesn't care about visual quality as much as pixel availability.
        img = img.resize((new_width, new_height), Image.Resampling.LANCZOS)
        
        # Update metrics for the new size
        width, height = img.size
        total_pixels = width * height
        pixels_available_for_data = total_pixels - pixels_for_header
        
        # Re-calc bit depth (try to use lowest possible density for the new size)
        for bpc in range(1, 5):
            capacity_bits = pixels_available_for_data * bpc * 3
            if capacity_bits >= data_bits_count:
                bits_per_channel = bpc
                break
        else:
             # Should practically never happen with the resize logic above
             bits_per_channel = 4

    # --- Prepare Data ---
    
    # 1. Header Bits (always 1 bit per channel)
    # bits_per_channel (8 bits)
    header_data = struct.pack('>B', bits_per_channel) + struct.pack('>I', len(secret_data))
    
    header_bits = []
    for byte in header_data:
        for i in range(8):
            header_bits.append((byte >> (7 - i)) & 1)
            
    # 2. Secret Data Bits
    data_bits = []
    for byte in secret_data:
        for i in range(8):
            data_bits.append((byte >> (7 - i)) & 1)
            
    # --- Embed ---
    pixels = img.load()
    
    current_pixel_idx = 0
    
    # Embed Header
    header_idx = 0
    while header_idx < len(header_bits):
        x = current_pixel_idx % width
        y = current_pixel_idx // width
        r, g, b = pixels[x, y]
        channels = [r, g, b]
        
        for c in range(3):
            if header_idx < len(header_bits):
                # LSB substitution (bit 0)
                channels[c] = (channels[c] & ~1) | header_bits[header_idx]
                header_idx += 1
                
        pixels[x, y] = tuple(channels)
        current_pixel_idx += 1
        
    # Embed Data
    # We continue from current_pixel_idx
    data_idx = 0
    total_data_bits = len(data_bits)
    
    # Iterate remaining pixels
    while data_idx < total_data_bits and current_pixel_idx < total_pixels:
        x = current_pixel_idx % width
        y = current_pixel_idx // width
        r, g, b = pixels[x, y]
        channels = [r, g, b]
        
        for c in range(3):
            # For each channel, embed 'bits_per_channel' bits
            # from LSB up. e.g. if bpc=2, modify bit 0 and bit 1.
            for bit_pos in range(bits_per_channel):
                if data_idx < total_data_bits:
                    bit_val = data_bits[data_idx]
                    # Modify specific bit position
                    channels[c] = set_bit(channels[c], bit_pos, bit_val)
                    data_idx += 1
                else:
                    break
        
        pixels[x, y] = tuple(channels)
        current_pixel_idx += 1

    img.save(output_path)
    return output_path

def decode_image(image_path: str) -> bytes:
    img = Image.open(image_path)
    img = img.convert('RGB')
    pixels = img.load()
    width, height = img.size
    total_pixels = width * height
    
    current_pixel_idx = 0
    
    # --- Read Header ---
    # 40 bits total. 1 bit per channel.
    header_bits = []
    bits_needed = 40
    
    while len(header_bits) < bits_needed and current_pixel_idx < total_pixels:
        x = current_pixel_idx % width
        y = current_pixel_idx // width
        r, g, b = pixels[x, y]
        for val in [r, g, b]:
            if len(header_bits) < bits_needed:
                header_bits.append(val & 1)
        current_pixel_idx += 1
        
    if len(header_bits) < 40:
        raise ValueError("Image too small or corrupted header.")
        
    # Convert bits to bytes
    header_bytes = bytearray()
    for i in range(0, 40, 8):
        byte_val = 0
        for b in range(8):
            byte_val = (byte_val << 1) | header_bits[i + b]
        header_bytes.append(byte_val)
        
    bits_per_channel = header_bytes[0]
    data_len = struct.unpack('>I', header_bytes[1:5])[0]
    
    if bits_per_channel < 1 or bits_per_channel > 8:
         raise ValueError(f"Invalid bits_per_channel detected: {bits_per_channel}")

    # --- Read Data ---
    total_data_bits = data_len * 8
    extracted_bits = []
    
    # Provide a limit to prevent memory exhaustion on massive fake lengths
    # Check max possible capacity first?
    # Not strictly necessary but good practice. 
    
    # Read rest of pixels
    # current_pixel_idx is already advanced past header
    
    while len(extracted_bits) < total_data_bits and current_pixel_idx < total_pixels:
        x = current_pixel_idx % width
        y = current_pixel_idx // width
        r, g, b = pixels[x, y]
        channels = [r, g, b]
        
        for c in range(3):
            for bit_pos in range(bits_per_channel):
                if len(extracted_bits) < total_data_bits:
                     # Read bit at bit_pos
                     bit_val = (channels[c] >> bit_pos) & 1
                     extracted_bits.append(bit_val)
                else:
                     break
        current_pixel_idx += 1
        
    if len(extracted_bits) < total_data_bits:
        raise ValueError("Incomplete data. Image may be cropped or corrupted.")
        
    # Convert extracted bits to bytes
    result_bytes = bytearray()
    for i in range(0, len(extracted_bits), 8):
        byte_val = 0
        for b in range(8):
            if i+b < len(extracted_bits):
                byte_val = (byte_val << 1) | extracted_bits[i+b]
        result_bytes.append(byte_val)
        
    return bytes(result_bytes)

def check_capacity(image_path: str) -> int:
    img = Image.open(image_path)
    img = ImageOps.exif_transpose(img)
    width, height = img.size
    
    # Header takes 40 bits = 5 bytes
    # Header is always 1 bpc
    pixels_for_header = math.ceil(40 / 3)
    remaining_pixels = (width * height) - pixels_for_header
    
    # Max capacity with 4 bits per channel (aggressive)
    # 4 bits * 3 channels = 12 bits per pixel
    max_bits = remaining_pixels * 12
    return max_bits // 8
