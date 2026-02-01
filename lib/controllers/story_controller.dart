import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:fairy_tales_app/services/fal_service.dart';
import 'package:fairy_tales_app/services/llm_service.dart';
import 'package:ffmpeg_kit_flutter_full_gpl/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_full_gpl/return_code.dart';

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
  bool isGeneratingImages = false; // NEW: for progressive display
  int currentImageIndex = 0; // NEW: which image is being generated

  String? finalVideoPath; // NEW: merged video path

  bool get hasVideos => finalVideoPath != null;
  int get totalScenes => _scenes.length;

  // Step 1: Generate Story Text Only
  Future<void> generateStoryOnly(String prompt, XFile userPhoto, {int sceneCount = 3}) async {
    try {
      reset(); // ensure clean state
      isProcessing = true;
      notifyListeners();

      _updateStatus('Consulting the wise storyteller...', true);

      // Generate Story Script via LLM
      storyData = await _llm.generateStory(prompt, sceneCount: sceneCount);

      debugPrint('LLM story data received: $storyData');
      _scenes = (storyData?['scenes'] as List).cast<Map<String, dynamic>>();

      if (_scenes.isEmpty) {
        throw Exception('No scenes generated');
      }

      _updateStatus('Story written! Please read.', false);
      isProcessing = false;
      isStoryReady = true;
      notifyListeners();

    } catch (e) {
      _updateStatus('Story generation failed: $e', false);
      isProcessing = false;
      notifyListeners();
      debugPrint(e.toString());
    }
  }

  // Step 2: Generate Images from Story (PROGRESSIVE)
  Future<void> generateImagesFromStory(XFile userPhoto) async {
    try {
      isProcessing = true;
      isStoryReady = false;
      isGeneratingImages = true; // Show progressive UI
      currentImageIndex = 0;
      generatedImageUrls.clear();
      notifyListeners();

      _updateStatus('Uploading your portrait to the magic realm...', true);

      // Upload User Photo -> Convert to Base64
      final bytes = await userPhoto.readAsBytes();
      final base64Image = base64Encode(bytes);
      final mimeType = userPhoto.name.toLowerCase().endsWith('.png') ? 'image/png' : 'image/jpeg';
      final userPhotoUrl = 'data:$mimeType;base64,$base64Image';

      debugPrint('Starting image generation for ${_scenes.length} scenes...');

      for (int i = 0; i < _scenes.length; i++) {
        final scene = _scenes[i];
        currentImageIndex = i;

        debugPrint('Generating image for scene ${i + 1}...');
        _updateStatus('✨ Painting scene ${i + 1} of ${_scenes.length}...', true);
        notifyListeners(); // Update UI to show current progress

        // Generate Image
        final imgPrompt = scene['image_prompt'];
        final imgJob = await _fal.submitImageGeneration(prompt: imgPrompt, imageUrl: userPhotoUrl);
        debugPrint('Image job submitted. Polling...');
        final imgUrl = await _fal.pollForResult(imgJob, isVideo: false);
        debugPrint('Image URL received: $imgUrl');

        generatedImageUrls.add(imgUrl);
        notifyListeners(); // NEW: Update UI immediately when image is ready
      }

      // All images ready for approval
      _updateStatus('All scenes painted! Ready to animate?', false);
      isProcessing = false;
      isGeneratingImages = false;
      areImagesReady = true;
      notifyListeners();

    } catch (e) {
      _updateStatus('Image painting failed: $e', false);
      isProcessing = false;
      isGeneratingImages = false;
      isStoryReady = true; // Go back to story
      notifyListeners();
      debugPrint(e.toString());
    }
  }

  // Step 3: Generate Videos and Merge
  Future<void> generateVideosFromImages() async {
    try {
      if (generatedImageUrls.length != _scenes.length) {
        throw Exception('Mismatch between images and scenes');
      }

      isProcessing = true;
      areImagesReady = false;
      generatedVideoPaths.clear();
      finalVideoPath = null;
      notifyListeners();

      // Generate all video clips
      for (int i = 0; i < _scenes.length; i++) {
        final scene = _scenes[i];
        final imgUrl = generatedImageUrls[i];

        _updateStatus('🎬 Animating scene ${i + 1} of ${_scenes.length}...', true);
        notifyListeners();

        final vidPrompt = scene['video_prompt'];
        final vidJob = await _fal.submitVideoGeneration(prompt: vidPrompt, imageUrl: imgUrl);
        final vidUrl = await _fal.pollForResult(vidJob, isVideo: true);

        if (kIsWeb) {
          generatedVideoPaths.add(vidUrl);
        } else {
          final vidFile = await _downloadFile(vidUrl, 'scene_$i.mp4');
          generatedVideoPaths.add(vidFile.path);
        }

        notifyListeners();
      }

      // Merge videos into one (mobile only)
      if (!kIsWeb && generatedVideoPaths.length > 1) {
        _updateStatus('📽️ Merging your fairy tale...', true);
        notifyListeners();

        final mergedPath = await _concatenateVideos(generatedVideoPaths);
        finalVideoPath = mergedPath;
      } else if (generatedVideoPaths.isNotEmpty) {
        // Single video or web - use first/only video
        finalVideoPath = generatedVideoPaths.first;
      }

      _updateStatus('✨ Your fairy tale is complete!', false);
      isProcessing = false;
      notifyListeners();

    } catch (e) {
      _updateStatus('Video creation failed: $e', false);
      isProcessing = false;
      areImagesReady = true;
      notifyListeners();
      debugPrint(e.toString());
    }
  }

  /// Concatenate multiple videos into one using FFmpeg
  Future<String> _concatenateVideos(List<String> videoPaths) async {
    final directory = await getApplicationDocumentsDirectory();
    final outputPath = '${directory.path}/fairy_tale_final.mp4';
    final listFilePath = '${directory.path}/videos_list.txt';

    // Create a file list for FFmpeg concat demuxer
    final listContent = videoPaths.map((p) => "file '$p'").join('\n');
    await File(listFilePath).writeAsString(listContent);

    debugPrint('FFmpeg: Concatenating ${videoPaths.length} videos...');

    // FFmpeg concat command
    final session = await FFmpegKit.execute(
      '-f concat -safe 0 -i "$listFilePath" -c copy "$outputPath" -y'
    );

    final returnCode = await session.getReturnCode();

    if (ReturnCode.isSuccess(returnCode)) {
      debugPrint('FFmpeg: Success! Output: $outputPath');
      // Cleanup temp list file
      await File(listFilePath).delete();
      return outputPath;
    } else {
      final logs = await session.getOutput();
      debugPrint('FFmpeg failed: $logs');
      throw Exception('Video merge failed');
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
    isGeneratingImages = false;
    currentImageIndex = 0;
    finalVideoPath = null;
    _scenes.clear();
    storyData = null;
    statusMessage = '';
    isProcessing = false;
    notifyListeners();
  }
}
