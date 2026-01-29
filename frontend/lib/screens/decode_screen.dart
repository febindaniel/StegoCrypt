import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../services/api_service.dart';
import '../widgets/dashed_box.dart';

class DecodeScreen extends StatefulWidget {
  const DecodeScreen({super.key});

  @override
  State<DecodeScreen> createState() => _DecodeScreenState();
}

class _DecodeScreenState extends State<DecodeScreen> {
  File? _selectedImage;
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  
  // To handle the result state
  String? _resultText;
  String? _savedFilePath;

  final ApiService _apiService = ApiService();

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
        _resultText = null;
        _savedFilePath = null;
      });
    }
  }

  Future<void> _decode() async {
    if (_selectedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select an image')));
      return;
    }
    if (_passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password is required')));
      return;
    }
    
    setState(() {
      _isLoading = true;
      _resultText = null;
      _savedFilePath = null;
    });

    try {
      final result = await _apiService.decode(
        imageFile: _selectedImage!,
        password: _passwordController.text,
      );

      // Handle result
      if (result['type'] == 'text') {
        setState(() {
          _resultText = result['content'];
        });
      } else if (result['type'] == 'file') {
        String filename = result['filename'];
        String? savePath;
        
        if (Platform.isAndroid || Platform.isIOS) {
           final directory = await getTemporaryDirectory();
           savePath = '${directory.path}/$filename';
        } else {
          final FileSaveLocation? saveLoc = await getSaveLocation(
            suggestedName: filename,
          );
          if (saveLoc != null) savePath = saveLoc.path;
        }
        
        if (savePath != null) {
          File f = File(savePath);
          await f.writeAsBytes(base64Decode(result['content']));
          setState(() {
            _savedFilePath = savePath;
          });
          
          if (mounted) {
             if (Platform.isAndroid || Platform.isIOS) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('File Extracted! Sharing...')));
                await Share.shareXFiles([XFile(savePath)], text: "Decrypted File: $filename");
             } else {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('File saved to $savePath')));
             }
          }
        }
      }

    } catch (e) {
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
            // Top Section (Input | Output)
            LayoutBuilder(
              builder: (context, constraints) {
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
                          const Text("Encrypted Image", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          const Text("Select the image containing hidden message", style: TextStyle(color: Colors.grey, fontSize: 13)),
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
                                            Image.file(_selectedImage!, fit: BoxFit.contain),
                                            Positioned(
                                              bottom: 12,
                                              right: 12,
                                              child: Container(
                                                padding: const EdgeInsets.all(8),
                                                decoration: const BoxDecoration(
                                                  color: Colors.black54,
                                                  shape: BoxShape.circle,
                                                ),
                                                child: const Icon(Icons.lock, color: Colors.white, size: 20),
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
                                          Text("Drop encrypted image here", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Theme.of(context).colorScheme.onSurface)),
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
                    
                    // Extracted Message / Output
                    Expanded(
                      flex: isWide ? 1 : 0,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Extracted Message", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          const Text("Decrypted secret message", style: TextStyle(color: Colors.grey, fontSize: 13)),
                          const SizedBox(height: 12),
                          
                          Container(
                            height: 300,
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Theme.of(context).colorScheme.outline),
                            ),
                            child: _resultText != null || _savedFilePath != null
                              ? SingleChildScrollView(
                                  child: _savedFilePath != null 
                                    ? Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          const Icon(Icons.check_circle_outline, size: 64, color: Colors.green),
                                          const SizedBox(height: 16),
                                          const Text("File Extracted Successfully!", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                          const SizedBox(height: 8),
                                          Text(_savedFilePath!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
                                          if (Platform.isAndroid || Platform.isIOS)
                                            Padding(
                                              padding: const EdgeInsets.only(top: 8.0),
                                              child: TextButton.icon(
                                                onPressed: () {
                                                  Share.shareXFiles([XFile(_savedFilePath!)], text: "Decrypted File");
                                                },
                                                icon: const Icon(Icons.share),
                                                label: const Text("Share Again"),
                                              ),
                                            )
                                        ]
                                      )
                                    : SelectableText(_resultText!, style: const TextStyle(fontSize: 14)),
                                )
                              : Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.lock_open_rounded, size: 48, color: Theme.of(context).dividerColor),
                                      const SizedBox(height: 16),
                                      Text("Decrypted message will appear here", style: TextStyle(color: Theme.of(context).disabledColor)),
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
             
             // Decryption Settings
             const Text("Decryption Settings", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
             const Text("Enter the password to decrypt the message", style: TextStyle(color: Colors.grey)),
             const SizedBox(height: 24),
             
             // Password
             TextFormField(
               controller: _passwordController,
               decoration: const InputDecoration(
                 labelText: "Decryption Password",
                 hintText: "Enter the encryption password...",
                 prefixIcon: Icon(Icons.key),
               ),
               obscureText: true,
             ),
             
             const SizedBox(height: 32),
             
             SizedBox(
               height: 56,
               child: FilledButton.icon(
                 onPressed: _isLoading ? null : _decode,
                  icon: _isLoading 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.lock_open),
                 label: Text(_isLoading ? "DECRYPTING..." : "DECRYPT MESSAGE"),
               ),
             ),
        ],
      ),
    );
  }
}
