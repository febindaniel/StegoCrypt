import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart';
import 'package:image_picker/image_picker.dart'; 
import 'package:file_picker/file_picker.dart' as fp;
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../services/api_service.dart';
import '../widgets/dashed_box.dart';

class EncodeScreen extends StatefulWidget {
  const EncodeScreen({super.key});

  @override
  State<EncodeScreen> createState() => _EncodeScreenState();
}

class _EncodeScreenState extends State<EncodeScreen> {
  final _formKey = GlobalKey<FormState>();
  File? _selectedImage;
  bool _isText = true;
  final _textController = TextEditingController();
  final _passwordController = TextEditingController();
  File? _secretFile;
  bool _isLoading = false;
  String? _statusMessage;
  int _capacity = 0;
  
  // To show the "Saved" state visually in the right panel
  String? _lastSavedPath;

  final ApiService _apiService = ApiService();

  double _progress = 0.0;
  String _estimatedTime = "";
  
  Future<void> _simulateProgress(int fileSize) async {
    _progress = 0.0;
    double estimatedSeconds = (fileSize / (1024 * 1024)) * 1.5 + 2; 
    if (estimatedSeconds < 2) estimatedSeconds = 2;
    _estimatedTime = "${estimatedSeconds.toStringAsFixed(1)}s";
    
    int steps = 100;
    int stepTime = (estimatedSeconds * 1000 / steps).round();
    
    for (int i = 0; i < steps; i++) {
   if (!_isLoading) return;
      await Future.delayed(Duration(milliseconds: stepTime));
      if (mounted) {
        setState(() {
           if (_progress < 0.9) _progress += 0.009;
        });
      }
    }
  }

  Future<void> _pickImage() async {
    String? path;
    
    if (Platform.isAndroid || Platform.isIOS) {
      final XFile? photo = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (photo != null) path = photo.path;
    } else {
      const XTypeGroup typeGroup = XTypeGroup(
        label: 'images',
        extensions: <String>['jpg', 'png', 'jpeg', 'bmp'],
      );
      final XFile? file = await openFile(acceptedTypeGroups: <XTypeGroup>[typeGroup]);
      if (file != null) path = file.path;
    }
    
    if (path != null) {
      setState(() {
        _selectedImage = File(path!);
        _capacity = 0;
        _statusMessage = "Checking capacity...";
        _lastSavedPath = null; 
      });
      
      try {
        int cap = await _apiService.checkCapacity(_selectedImage!);
        setState(() {
          _capacity = cap;
          _statusMessage = "Max Capacity: ${(_capacity / 1024).toStringAsFixed(2)} KB";
        });
      } catch (e) {
        setState(() {
          _statusMessage = "Failed to check capacity";
        });
      }
    }
  }

  Future<void> _pickSecretFile() async {
    String? path;
    
    if (Platform.isAndroid || Platform.isIOS) {
       fp.FilePickerResult? result = await fp.FilePicker.platform.pickFiles();
       if (result != null) path = result.files.single.path;
    } else {
       final XFile? file = await openFile();
       if (file != null) path = file.path;
    }
    
    if (path != null) {
      setState(() {
        _secretFile = File(path!);
      });
    }
  }

  Future<void> _encode() async {
    if (_selectedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select an image')));
      return;
    }
    if (_passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password is required')));
      return;
    }
    if (!_isText && _secretFile == null) {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a file to hide')));
       return;
    }

    setState(() {
      _isLoading = true;
      _statusMessage = "Preparing...";
      _progress = 0.1;
      _lastSavedPath = null;
    });

    try {
      String savePath;
      
      if (Platform.isAndroid || Platform.isIOS) {
        // Mobile: Save to temp then share
        final directory = await getTemporaryDirectory();
        savePath = '${directory.path}/encrypted_${DateTime.now().millisecondsSinceEpoch}.png';
      } else {
        // Desktop: Ask user
        final FileSaveLocation? result = await getSaveLocation(
          suggestedName: 'secret_image.png',
          acceptedTypeGroups: [
            const XTypeGroup(label: 'PNG Image', extensions: ['png'])
          ],
        );

        if (result == null) {
           setState(() {
            _isLoading = false;
            _statusMessage = "Cancelled";
          });
          return;
        }
        savePath = result.path;
        if (!savePath.endsWith('.png')) savePath += ".png";
      }

      int payloadSize = _isText ? _textController.text.length : (_secretFile!.lengthSync());
      _simulateProgress(payloadSize); 
      
      setState(() {
        _statusMessage = "Encoding & Encrypting... (Est: $_estimatedTime)";
      });

      await _apiService.encode(
        imageFile: _selectedImage!,
        isText: _isText,
        text: _textController.text,
        secretFile: _secretFile,
        password: _passwordController.text,
        savePath: savePath,
      );

      _progress = 1.0;

      if (mounted) {
        setState(() {
          _statusMessage = "Success! Saved.";
          _lastSavedPath = savePath;
        });

        if (Platform.isAndroid || Platform.isIOS) {
           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sharing Image...')));
           await Share.shareXFiles([XFile(savePath)], text: "Encrypted Image");
        } else {
           ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Saved to $savePath')));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
        setState(() {
          _statusMessage = "Error: $e";
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _progress = 0.0;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Section: Two Columns (Input Image | Output Image)
            LayoutBuilder(
              builder: (context, constraints) {
                // If wide enough, show side-by-side, else stack
                bool isWide = constraints.maxWidth > 800;
                
                return Flex(
                  direction: isWide ? Axis.horizontal : Axis.vertical,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Input Image
                    Expanded(
                      flex: isWide ? 1 : 0,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Input Image", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          const Text("Select an image to hide your message in", style: TextStyle(color: Colors.grey, fontSize: 13)),
                          const SizedBox(height: 12),
                          
                          InkWell(
                            onTap: _pickImage,
                            borderRadius: BorderRadius.circular(12),
                            child: DashedBox(
                              color: Theme.of(context).colorScheme.outline,
                              child: Container(
                                height: 300,
                                width: double.infinity,
                                alignment: Alignment.center,
                                child: _selectedImage != null
                                    ? ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: Stack(
                                          fit: StackFit.expand,
                                          children: [
                                            Image.file(_selectedImage!, fit: BoxFit.cover),
                                            Positioned(
                                              bottom: 12,
                                              right: 12,
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                decoration: BoxDecoration(
                                                  color: Colors.black.withOpacity(0.7),
                                                  borderRadius: BorderRadius.circular(20),
                                                ),
                                                child: Text(
                                                  "Max: ${(_capacity / 1024).toStringAsFixed(2)} KB",
                                                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                                ),
                                              ),
                                            )
                                          ],
                                        ),
                                      )
                                    : Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.cloud_upload_outlined, size: 48, color: Theme.of(context).colorScheme.secondary),
                                          const SizedBox(height: 16),
                                          Text("Drop image here", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Theme.of(context).colorScheme.onSurface)),
                                          const SizedBox(height: 4),
                                          Text("Click to browse or drag and drop", style: TextStyle(color: Theme.of(context).colorScheme.secondary)),
                                        ],
                                      ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    SizedBox(width: isWide ? 24 : 0, height: isWide ? 0 : 24),
                    
                    // Output Image
                    Expanded(
                      flex: isWide ? 1 : 0,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Output Image", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          const Text("Encrypted image with hidden message", style: TextStyle(color: Colors.grey, fontSize: 13)),
                          const SizedBox(height: 12),
                          
                          Container(
                            height: 300,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Theme.of(context).colorScheme.outline),
                            ),
                            child: _lastSavedPath != null 
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                       Image.file(File(_lastSavedPath!), fit: BoxFit.cover),
                                       Center(
                                         child: Container(
                                           padding: const EdgeInsets.all(12),
                                            decoration: const BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: Colors.green,
                                            ),
                                            child: const Icon(Icons.check, color: Colors.white, size: 32),
                                         ),
                                       )
                                    ],
                                  ),
                                )
                              : Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.image_not_supported_outlined, size: 48, color: Theme.of(context).dividerColor),
                                      const SizedBox(height: 16),
                                      Text("Encrypted image will appear here", style: TextStyle(color: Theme.of(context).disabledColor)),
                                    ],
                                  ),
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),

            const SizedBox(height: 32),
            const Divider(),
            const SizedBox(height: 24),

            // Bottom Section: Settings
            const Text("Encryption Settings", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Text("Enter your secret message and password", style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 24),

            Row(
              children: [
                const Text("Secret Type:", style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(width: 16),
                ChoiceChip(
                  label: const Text("Message"),
                  selected: _isText,
                  onSelected: (val) {
                    setState(() => _isText = true);
                  },
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text("File"),
                  selected: !_isText,
                  onSelected: (val) {
                    setState(() => _isText = false);
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),

            if (_isText)
              TextFormField(
                controller: _textController,
                decoration: const InputDecoration(
                  labelText: "Secret Message",
                  hintText: "Enter the message you want to hide...",
                  alignLabelWithHint: true,
                ),
                maxLines: 4,
              )
            else
              InkWell(
                onTap: _pickSecretFile,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Theme.of(context).colorScheme.outline),
                    borderRadius: BorderRadius.circular(8),
                    color: Theme.of(context).inputDecorationTheme.fillColor,
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.attach_file),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _secretFile != null ? _secretFile!.path : "Select a file to hide...",
                          style: TextStyle(
                            color: _secretFile != null ? Theme.of(context).colorScheme.onSurface : Theme.of(context).hintColor,
                          ),
                        ),
                      ),
                      if (_secretFile != null)
                        Text("(${(_secretFile!.lengthSync()/1024).toStringAsFixed(1)} KB)", style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            
            const SizedBox(height: 16),

            TextFormField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: "Encryption Password",
                hintText: "Enter a strong password...",
                suffixIcon: Icon(Icons.visibility_off_outlined), 
              ),
            ),
            
            const SizedBox(height: 32),
            
            SizedBox(
              height: 56,
              child: FilledButton.icon(
                onPressed: _isLoading ? null : _encode,
                icon: _isLoading 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.lock_outline),
                label: Text(_isLoading ? "ENCODING..." : "ENCRYPT MESSAGE"),
              ),
            ),
            
            if (_statusMessage != null && !_statusMessage!.startsWith("Success"))
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: Text(
                  _statusMessage!,
                  style: TextStyle(
                    color: _statusMessage!.startsWith("Error") ? Colors.red : Theme.of(context).colorScheme.secondary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
