import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:fairy_tales_app/services/fal_service.dart';
import 'package:fairy_tales_app/services/llm_service.dart';

class StoryController extends ChangeNotifier {
  final _llm = LLMService();
  final _fal = FalService();
  
  String statusMessage = '';
  bool isProcessing = false;
  
  Map<String, dynamic>? storyData;
  List<String> generatedImageUrls = [];
  List<String> generatedVideoPaths = [];
  
  // State for verification steps
  List<Map<String, dynamic>> _scenes = [];
  bool isStoryReady = false;
  bool areImagesReady = false;

  bool get hasVideos => generatedVideoPaths.isNotEmpty;

  // Step 1: Generate Story Text Only
  Future<void> generateStoryOnly(String prompt, XFile userPhoto) async {
    try {
      reset(); // ensure clean state
      isProcessing = true;
      notifyListeners();
      
      _updateStatus('Consulting the wise storyteller...', true);
      // Generate Story Script
      // MANUAL MODE: Bypass LLM per user request
      await Future.delayed(const Duration(milliseconds: 500));
      
      storyData = {
        "scenes": [
          {
            "text": "Scene 1: $prompt",
            "image_prompt": "Without changing the faces, facial features, hair or head shape, $prompt",
            "video_prompt": "cinematic 4k, $prompt"
          }
        ]
      };
      
      debugPrint('Manual story data created: $storyData');
      _scenes = (storyData?['scenes'] as List).cast<Map<String, dynamic>>();

      _updateStatus('Story written! Please read.', false);
      isProcessing = false;
      isStoryReady = true;
      notifyListeners();

    } catch (e) {
      _updateStatus('Story generation failed: $e', false);
      debugPrint(e.toString());
    }
  }

  // Step 2: Generate Images from Story
  Future<void> generateImagesFromStory(XFile userPhoto) async {
    try {
      isProcessing = true;
      isStoryReady = false; // Hide story UI
      notifyListeners();

      _updateStatus('Uploading photo to magic cloud...', true);
      // Upload User Photo -> Convert to Base64
      final bytes = await userPhoto.readAsBytes();
      final base64Image = base64Encode(bytes);
      final mimeType = userPhoto.name.toLowerCase().endsWith('.png') ? 'image/png' : 'image/jpeg';
      final userPhotoUrl = 'data:$mimeType;base64,$base64Image';
      
      generatedImageUrls.clear();
      
      debugPrint('Starting image generation for ${_scenes.length} scenes...');
      for (int i = 0; i < _scenes.length; i++) {
        final scene = _scenes[i];
        
        debugPrint('Generating image for scene ${i + 1}...');
        _updateStatus('Painting scene ${i + 1} of ${_scenes.length}...', true);
        // Generate Image
        final imgPrompt = scene['image_prompt'];
        final imgJob = await _fal.submitImageGeneration(prompt: imgPrompt, imageUrl: userPhotoUrl);
        debugPrint('Image job submitted. Polling...');
        final imgUrl = await _fal.pollForResult(imgJob, isVideo: false);
        debugPrint('Image URL received: $imgUrl');
        generatedImageUrls.add(imgUrl);
      }

      // Ready for user approval
      _updateStatus('Images ready! Please approve.', false);
      isProcessing = false;
      areImagesReady = true;
      notifyListeners();

    } catch (e) {
      _updateStatus('Image painting failed: $e', false);
      isStoryReady = true; // Go back to story usage
      notifyListeners();
      debugPrint(e.toString());
    }
  }

  // Step 3: Generate Videos
  Future<void> generateVideosFromImages() async {
    try {
      if (generatedImageUrls.length != _scenes.length) {
        throw Exception('Mismatch between images and scenes');
      }

      isProcessing = true;
      areImagesReady = false; // Hide approval UI
      notifyListeners();

      generatedVideoPaths.clear();

      for (int i = 0; i < _scenes.length; i++) {
         final scene = _scenes[i];
         final imgUrl = generatedImageUrls[i];

         _updateStatus('Animating scene ${i + 1} of ${_scenes.length}...', true);
         
         // Generate Video
         final vidPrompt = scene['video_prompt'];
         final vidJob = await _fal.submitVideoGeneration(prompt: vidPrompt, imageUrl: imgUrl);
         final vidUrl = await _fal.pollForResult(vidJob, isVideo: true);
         
         // Handle Result
         if (kIsWeb) {
             generatedVideoPaths.add(vidUrl);
         } else {
             final vidFile = await _downloadFile(vidUrl, 'scene_$i.mp4');
             generatedVideoPaths.add(vidFile.path);
         }
         
         notifyListeners();
      }
      
      _updateStatus('Your fairy tale is ready!', false);
      isProcessing = false;

    } catch (e) {
      _updateStatus('Video generation failed: $e', false);
      areImagesReady = true; // allow retry
      notifyListeners();
      debugPrint(e.toString());
    }
  }

  void _updateStatus(String msg, bool processing) {
    statusMessage = msg;
    isProcessing = processing;
    notifyListeners();
  }

  Future<File> _downloadFile(String url, String filename) async {
    final response = await http.get(Uri.parse(url));
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/$filename');
    await file.writeAsBytes(response.bodyBytes);
    return file;
  }

  void reset() {
    generatedVideoPaths.clear();
    generatedImageUrls.clear();
    areImagesReady = false;
    isStoryReady = false;
    _scenes.clear();
    storyData = null;
    statusMessage = '';
    isProcessing = false;
    notifyListeners();
  }
}
