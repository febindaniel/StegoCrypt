import zlib
import os
import json
import base64
from flask import Flask, request, send_file, jsonify
from werkzeug.utils import secure_filename
import tempfile
import shutil

from crypto import encrypt, decrypt
from steganography import encode_image, decode_image, check_capacity

app = Flask(__name__)

TEMP_DIR = os.path.join(os.getcwd(), 'temp')
if not os.path.exists(TEMP_DIR):
    os.makedirs(TEMP_DIR)

@app.route('/health', methods=['GET'])
def health():
    return jsonify({"status": "ok"})

@app.route('/capacity', methods=['POST'])
def capacity():
    # Check capacity of uploaded image
    if 'image' not in request.files:
        return jsonify({"error": "No image provided"}), 400
    
    file = request.files['image']
    with tempfile.NamedTemporaryFile(delete=False, suffix='.png') as tmp:
        file.save(tmp.name)
        tmp_path = tmp.name
        
    try:
        cap = check_capacity(tmp_path)
        os.remove(tmp_path)
        return jsonify({"capacity_bytes": cap})
    except Exception as e:
        if os.path.exists(tmp_path):
            os.remove(tmp_path)
        return jsonify({"error": str(e)}), 500

@app.route('/encode', methods=['POST'])
def encode_api():
    try:
        # Inputs: image, password, type (text/file), content (text) or file (file)
        if 'image' not in request.files:
            return jsonify({"error": "No image provided"}), 400
            
        password = request.form.get('password')
        if not password:
            return jsonify({"error": "Password required"}), 400
            
        is_text = request.form.get('is_text') == 'true'
        
        # Construct payload
        payload = {}
        if is_text:
            text = request.form.get('text', '')
            payload = {"type": "text", "content": text}
        else:
            if 'file' not in request.files:
                return jsonify({"error": "No file provided"}), 400
            f = request.files['file']
            file_data = f.read()
            # Encode file content to base64 string for JSON serialization
            b64_content = base64.b64encode(file_data).decode('utf-8')
            payload = {"type": "file", "filename": secure_filename(f.filename), "content": b64_content}
            
        payload_bytes = json.dumps(payload).encode('utf-8')
        
        # Compress
        compressed_payload = zlib.compress(payload_bytes)
        
        # Encrypt
        encrypted_data = encrypt(compressed_payload, password)
        
        # Save temp image
        img_file = request.files['image']
        # Preserve extension or force png
        ext = os.path.splitext(img_file.filename)[1]
        if ext.lower() not in ['.png', '.bmp']:
            ext = '.png' 
            
        with tempfile.NamedTemporaryFile(delete=False, suffix=ext) as tmp_src:
            img_file.save(tmp_src.name)
            src_path = tmp_src.name
            
        out_path = src_path + "_encoded" + ext
        
        # Steganography Encode
        try:
            encode_image(src_path, encrypted_data, out_path)
        except ValueError as e:
            # Capacity error
            os.remove(src_path)
            return jsonify({"error": str(e)}), 400
            
        os.remove(src_path)
        
        return send_file(out_path, as_attachment=True, download_name=f"encoded_{img_file.filename}")
        
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/decode', methods=['POST'])
def decode_api():
    try:
        if 'image' not in request.files:
             return jsonify({"error": "No image provided"}), 400
             
        password = request.form.get('password')
        if not password:
            return jsonify({"error": "Password required"}), 400
            
        img_file = request.files['image']
        with tempfile.NamedTemporaryFile(delete=False, suffix='.png') as tmp:
            img_file.save(tmp.name)
            src_path = tmp.name
            
        # Steganography Decode
        try:
            encrypted_data = decode_image(src_path)
        except Exception as e:
            os.remove(src_path)
            return jsonify({"error": "Failed to extract data. Image might not contain hidden data or is corrupted."}), 400
            
        os.remove(src_path)
        
        # Decrypt
        try:
            decrypted_bytes = decrypt(encrypted_data, password)
        except Exception as e:
            return jsonify({"error": "Decryption failed. Wrong password."}), 401
            
        # Decompress
        try:
            payload_bytes = zlib.decompress(decrypted_bytes)
        except Exception as e:
             # Backward compatibility: current images are not compressed.
             # If decompress fails, try assuming it's uncompressed (if compatible json).
             # But zlib usually throws specific header error. 
             # However, since we just rewrote stego logic, old images are likely incompatible anyway due to header change.
             # So we can enforce compression.
             return jsonify({"error": "Decompression failed. Data corrupted or legacy format."}), 500
             
        # Parse Payload
        try:
            payload = json.loads(payload_bytes.decode('utf-8'))
        except:
            return jsonify({"error": "Invalid data format recovered."}), 500
            
        return jsonify(payload)

    except Exception as e:
        return jsonify({"error": str(e)}), 500

if __name__ == '__main__':
    app.run(host='127.0.0.1', port=5000)
