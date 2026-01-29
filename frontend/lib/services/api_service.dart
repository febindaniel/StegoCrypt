
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
// ignore: depend_on_referenced_packages


import 'native_stego_service.dart';

class ApiService {
  static const String baseUrl = 'http://127.0.0.1:5000';
  
  bool get _useNative => Platform.isAndroid || Platform.isIOS;

  Future<bool> checkHealth() async {
    if (_useNative) return true; // Native is always "healthy" (no server)
    try {
      final response = await http.get(Uri.parse('$baseUrl/health'));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<int> checkCapacity(File imageFile) async {
    if (_useNative) {
      return await NativeStegoService.checkCapacity(imageFile);
    }
    
    var request = http.MultipartRequest('POST', Uri.parse('$baseUrl/capacity'));
    request.files.add(await http.MultipartFile.fromPath('image', imageFile.path));
    
    try {
      var response = await request.send();
      if (response.statusCode == 200) {
        var respStr = await response.stream.bytesToString();
        var json = jsonDecode(respStr);
        return json['capacity_bytes'];
      }
      return 0;
    } catch (e) {
      return 0;
    }
  }

  Future<File?> encode({
    required File imageFile,
    required bool isText,
    String? text,
    File? secretFile,
    required String password,
    required String savePath,
  }) async {
    if (_useNative) {
      return await NativeStegoService.encode(
        imageFile: imageFile, 
        isText: isText, 
        password: password, 
        savePath: savePath, 
        text: text, 
        secretFile: secretFile
      );
    }

    var request = http.MultipartRequest('POST', Uri.parse('$baseUrl/encode'));
    request.files.add(await http.MultipartFile.fromPath('image', imageFile.path));
    request.fields['password'] = password;
    request.fields['is_text'] = isText.toString();
    
    if (isText && text != null) {
      request.fields['text'] = text;
    } else if (secretFile != null) {
      request.files.add(await http.MultipartFile.fromPath('file', secretFile.path));
    }

    try {
      var response = await request.send();
      if (response.statusCode == 200) {
        var bytes = await response.stream.toBytes();
        var file = File(savePath);
        await file.writeAsBytes(bytes);
        return file;
      } else {
         var respStr = await response.stream.bytesToString(); 
         throw Exception("Encoding failed: $respStr");
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> decode({
    required File imageFile,
    required String password,
  }) async {
    if (_useNative) {
      return await NativeStegoService.decode(
        imageFile: imageFile, 
        password: password
      );
    }

    var request = http.MultipartRequest('POST', Uri.parse('$baseUrl/decode'));
    request.files.add(await http.MultipartFile.fromPath('image', imageFile.path));
    request.fields['password'] = password;

    try {
      var response = await request.send();
      var respStr = await response.stream.bytesToString();
      
      if (response.statusCode == 200) {
        return jsonDecode(respStr);
      } else {
        throw Exception("Decoding failed: $respStr");
      }
    } catch (e) {
      rethrow;
    }
  }
}
