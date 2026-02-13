import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

class CloudinaryService {
  static final CloudinaryService _instance = CloudinaryService._internal();
  factory CloudinaryService() => _instance;
  CloudinaryService._internal();

  static bool _isInitialized = false;
  static String _cloudName = '';
  static String _uploadPreset = '';
  static String _apiKey = '';
  static String _apiSecret = '';

  static Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      _cloudName = dotenv.env['CLOUDINARY_CLOUD_NAME']?.trim() ?? '';
      _uploadPreset = dotenv.env['CLOUDINARY_UPLOAD_PRESET']?.trim() ?? '';
      _apiKey = dotenv.env['CLOUDINARY_API_KEY']?.trim() ?? '';
      _apiSecret = dotenv.env['CLOUDINARY_API_SECRET']?.trim() ?? '';

      if (_cloudName.isEmpty) {
        throw Exception('CLOUDINARY_CLOUD_NAME is not set in .env file');
      }

      if (_uploadPreset.isEmpty) {
        throw Exception('CLOUDINARY_UPLOAD_PRESET is not set in .env file');
      }

      _isInitialized = true;
      debugPrint('✅ CloudinaryService initialized successfully');
      debugPrint('   Cloud: $_cloudName');
      debugPrint('   Preset: $_uploadPreset');
    } catch (e) {
      debugPrint('❌ Failed to initialize CloudinaryService: $e');
      _isInitialized = false;
      rethrow;
    }
  }

  static bool get isInitialized => _isInitialized;

  Future<String?> uploadImage(File imageFile) async {
    if (!_isInitialized) {
      try {
        await CloudinaryService.initialize();
      } catch (e) {
        throw StateError('CloudinaryService not initialized: $e');
      }
    }

    if (!_isInitialized) {
      throw StateError('CloudinaryService initialization failed');
    }

    try {
      if (!await imageFile.exists()) {
        throw Exception('Image file does not exist');
      }

      final uri = Uri.parse(
        'https://api.cloudinary.com/v1_1/$_cloudName/image/upload',
      );

      final request = http.MultipartRequest('POST', uri)
        ..fields['upload_preset'] = _uploadPreset
        ..fields['folder'] = 'hostels'
        ..fields['quality'] = 'auto:good'
        ..fields['fetch_format'] = 'auto'
        ..files.add(
          await http.MultipartFile.fromPath(
            'file',
            imageFile.path,
            filename: 'hostel_${DateTime.now().millisecondsSinceEpoch}.jpg',
          ),
        );

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      final responseData = utf8.decode(response.bodyBytes);
      final jsonData = json.decode(responseData);

      if (response.statusCode == 200) {
        final secureUrl = jsonData['secure_url'] as String?;
        if (secureUrl != null) {
          debugPrint('✅ Image uploaded successfully: $secureUrl');
          return secureUrl;
        } else {
          throw Exception('No secure_url in response');
        }
      } else {
        final errorMsg = jsonData['error']['message'] ?? 'Unknown error';
        throw Exception('Upload failed (${response.statusCode}): $errorMsg');
      }
    } catch (e) {
      debugPrint('❌ Error uploading to Cloudinary: $e');
      rethrow;
    }
  }

  Future<List<String>> uploadMultipleImages(List<File> imageFiles) async {
    List<String> uploadedUrls = [];
    List<String> errors = [];

    for (var image in imageFiles) {
      try {
        final url = await uploadImage(image);
        if (url != null) {
          uploadedUrls.add(url);
        }
      } catch (e) {
        errors.add('${image.path}: $e');
      }
    }

    if (errors.isNotEmpty) {
      debugPrint('⚠️ Some images failed to upload:');
      for (var e in errors) {
        debugPrint('   $e');
      }
    }

    return uploadedUrls;
  }

  Future<bool> deleteImage(String imageUrl) async {
    if (!_isInitialized) {
      try {
        await CloudinaryService.initialize();
      } catch (e) {
        debugPrint('❌ Cannot delete image: Cloudinary not initialized');
        return false;
      }
    }

    try {
      final uri = Uri.parse(imageUrl);
      final pathSegments = uri.pathSegments;
      final fileName = pathSegments.last;
      final publicId = fileName.split('.')[0];

      String fullPublicId = publicId;
      if (pathSegments.length > 1) {
        final folderPath = pathSegments
            .sublist(0, pathSegments.length - 1)
            .join('/');
        fullPublicId = '$folderPath/$publicId';
      }

      final timestamp = (DateTime.now().millisecondsSinceEpoch / 1000).round();
      final signature = _generateSignature(fullPublicId, timestamp, _apiSecret);

      final response = await http.post(
        Uri.parse('https://api.cloudinary.com/v1_1/$_cloudName/image/destroy'),
        body: {
          'public_id': fullPublicId,
          'api_key': _apiKey,
          'timestamp': timestamp.toString(),
          'signature': signature,
        },
      );

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        return jsonData['result'] == 'ok';
      }

      return false;
    } catch (e) {
      debugPrint('❌ Error deleting from Cloudinary: $e');
      return false;
    }
  }

  String _generateSignature(String publicId, int timestamp, String apiSecret) {
    final stringToSign = 'public_id=$publicId&timestamp=$timestamp$apiSecret';
    return sha1.convert(utf8.encode(stringToSign)).toString();
  }

  static CloudinaryService get instance => _instance;
}
