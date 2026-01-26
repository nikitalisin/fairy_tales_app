import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class FalService {
  // Key should ideally be in .env
  String get _falKey => dotenv.env['FAL_KEY'] ?? '';
  
  // Models
  static const String _imageModel = 'fal-ai/nano-banana/edit';
  static const String _videoModel = 'fal-ai/bytedance/seedance/v1/lite/image-to-video';

  Map<String, String> get _headers => {
    'Authorization': 'Key $_falKey',
    'Content-Type': 'application/json',
  };

  /// Uploads a file (bytes) to fal.ai storage and returns the URL
  Future<String> uploadFile(List<int> bytes, String filename) async {
    // Let's try the V3 storage endpoint:
    final uri = Uri.parse('https://v3.fal.media/files/upload');
    
    final request = http.MultipartRequest('POST', uri)
      ..headers.addAll({
        'Authorization': 'Key $_falKey',
      })
      ..files.add(http.MultipartFile.fromBytes(
        'file', 
        bytes,
        filename: filename,
        contentType: MediaType.parse(_getContentType(filename)),
      ));

    final response = await request.send();
    if (response.statusCode == 200 || response.statusCode == 201) {
      final respStr = await response.stream.bytesToString();
      final json = jsonDecode(respStr);
      return json['file_url'] ?? json['url']; 
    } else {
      throw Exception('Failed to upload file: ${response.statusCode}');
    }
  }

  String _getContentType(String filename) {
    if (filename.toLowerCase().endsWith('.jpg') || filename.toLowerCase().endsWith('.jpeg')) return 'image/jpeg';
    if (filename.toLowerCase().endsWith('.png')) return 'image/png';
    return 'application/octet-stream';
  }

  /// 1. Submit Job
  Future<Map<String, dynamic>> submitImageGeneration({
    required String prompt, 
    required String imageUrl
  }) async {
    final uri = Uri.parse('https://queue.fal.run/$_imageModel');
    
    final body = jsonEncode({
      "prompt": prompt,
      "image_urls": [imageUrl],
      "num_images": 1,
      "aspect_ratio": "16:9",
    });

    debugPrint('Submitting Image Gen to Fal.ai...');
    final response = await http.post(uri, headers: _headers, body: body);
    debugPrint('Fal.ai Response Code: ${response.statusCode}');

    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Error submitting image job: ${response.body}');
    }
  }

  Future<Map<String, dynamic>> submitVideoGeneration({
    required String prompt,
    required String imageUrl,
  }) async {
    final uri = Uri.parse('https://queue.fal.run/$_videoModel');
    
    final body = jsonEncode({
      "prompt": prompt,
      "image_url": imageUrl,
      "aspect_ratio": "16:9",
    });

    debugPrint('Submitting Video Gen to Fal.ai...');
    final response = await http.post(uri, headers: _headers, body: body);
    debugPrint('Fal.ai Response Code: ${response.statusCode}');

    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Error submitting video job: ${response.body}');
    }
  }

  /// 2. Poll Status & Get Result
  Future<String> pollForResult(Map<String, dynamic> jobInfo, {bool isVideo = false}) async {
    final requestId = jobInfo['request_id'];
    // Use the status_url from response if available, otherwise construct it
    String statusUrl = jobInfo['status_url'] ?? '';
    
    if (statusUrl.isEmpty) {
      final modelWithBase = isVideo ? _videoModel : _imageModel.replaceFirst('/edit', '');
      statusUrl = 'https://queue.fal.run/$modelWithBase/requests/$requestId/status';
    }

    debugPrint('Polling for status at: $statusUrl');

    int attempts = 0;
    while (attempts < 150) {
      await Future.delayed(const Duration(seconds: 2));
      
      final response = await http.get(Uri.parse(statusUrl), headers: _headers);
      if (response.statusCode != 200) {
         debugPrint('Poll attempt ${attempts + 1}: Status ${response.statusCode}');
         attempts++;
         continue;
      }

      final json = jsonDecode(response.body);
      final status = json['status'];
      debugPrint('Poll attempt ${attempts + 1}: $status');
      
      if (status == 'COMPLETED') {
        final responseUrl = json['response_url'];
        if (responseUrl != null) {
          return await _fetchFinalResult(responseUrl, isVideo: isVideo);
        } else {
           if (isVideo) {
             return json['video']['url'];
           } else {
             return json['images'][0]['url'];
           }
        }
      } else if (status == 'FAILED') {
        throw Exception('Generation Failed: ${json['error']}');
      }
      
      attempts++;
    }
    throw Exception('Timeout waiting for generation');
  }

  Future<String> _fetchFinalResult(String url, {required bool isVideo}) async {
    debugPrint('Fetching final result from: $url');
    final response = await http.get(Uri.parse(url), headers: _headers);
    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      if (isVideo) {
         return json['video']['url'];
      } else {
         return json['images'][0]['url'];
      }
    }
    throw Exception('Failed to fetch final result JSON');
  }
}
