import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:fairy_tales_app/controllers/story_controller.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized(); // Initialize media_kit
  await dotenv.load(fileName: ".env");
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => StoryController()),
      ],
      child: const FairyTaleApp(),
    ),
  );
}

class FairyTaleApp extends StatelessWidget {
  const FairyTaleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fairy Tale Generator',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        textTheme: GoogleFonts.cinzelTextTheme(Theme.of(context).textTheme).apply(
          bodyColor: Colors.white,
          displayColor: Colors.amberAccent,
        ),
      ),
      home: const StoryScreen(),
    );
  }
}

class StoryScreen extends StatefulWidget {
  const StoryScreen({super.key});

  @override
  State<StoryScreen> createState() => _StoryScreenState();
}

class _StoryScreenState extends State<StoryScreen> {
  final TextEditingController _promptController = TextEditingController();
  XFile? _imageFile;
  final ImagePicker _picker = ImagePicker();
  int _sceneCount = 3; // Default scene count

  @override
  void dispose() {
    _promptController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    final pickedFile = await _picker.pickImage(
      source: source,
      imageQuality: 50, // More aggressive compression
      maxWidth: 800,    // Smaller size
    );
    if (pickedFile != null) {
      setState(() {
        _imageFile = pickedFile;
      });
    }
  }

  Future<void> _createStory(StoryController controller) async {
    if (_imageFile == null || _promptController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add a photo and a story idea!')),
      );
      return;
    }
    
    // Dismiss keyboard
    FocusScope.of(context).unfocus();

    await controller.generateStoryOnly(_promptController.text, _imageFile!);
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<StoryController>();

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: NetworkImage('https://images.unsplash.com/photo-1518709268805-4e9042af9f23?q=80&w=2568&auto=format&fit=crop'),
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(Colors.black54, BlendMode.darken),
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('✨ Fairy Tale Maker ✨')
                      .animate()
                      .fadeIn(duration: 1000.ms)
                      .shimmer(duration: 2000.ms),
                  
                  const SizedBox(height: 30),

                  // Image Picker
                  GestureDetector(
                    onTap: () => _showImageSourceDialog(),
                    child: Container(
                      height: 200,
                      width: 200,
                      decoration: BoxDecoration(
                        color: Colors.white10,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.amberAccent, width: 2),
                        image: _imageFile != null
                            ? DecorationImage(
                                image: kIsWeb 
                                  ? NetworkImage(_imageFile!.path) 
                                  : FileImage(File(_imageFile!.path)) as ImageProvider,
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: _imageFile == null
                          ? const Icon(Icons.add_a_photo, size: 50, color: Colors.white70)
                          : null,
                    ).animate(target: _imageFile != null ? 1 : 0).scale(begin: const Offset(0.9, 0.9), end: const Offset(1, 1)),
                  ),
                  
                  const SizedBox(height: 20),

                  // Prompt Input
                  TextField(
                    controller: _promptController,
                    maxLines: 2,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.black45,
                      hintText: 'Tell me a story about...',
                      hintStyle: const TextStyle(color: Colors.white54),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: const BorderSide(color: Colors.amberAccent),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: const BorderSide(color: Colors.amber, width: 2),
                      ),
                    ),
                  ),

                  const SizedBox(height: 25),

                  // Scene Count Selector
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.black38,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.amberAccent.withOpacity(0.3)),
                    ),
                    child: Column(
                      children: [
                        Text(
                          '📜 Chapters of Legend',
                          style: TextStyle(
                            color: Colors.amberAccent.withOpacity(0.8),
                            fontSize: 14,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [2, 3, 4, 5].map((count) {
                            final isSelected = _sceneCount == count;
                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 6),
                              child: GestureDetector(
                                onTap: () => setState(() => _sceneCount = count),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeOutCubic,
                                  width: 50,
                                  height: 50,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isSelected ? Colors.amber.withOpacity(0.2) : Colors.transparent,
                                    border: Border.all(
                                      color: isSelected ? Colors.amber : Colors.white24,
                                      width: isSelected ? 2 : 1,
                                    ),
                                    boxShadow: isSelected
                                        ? [BoxShadow(color: Colors.amber.withOpacity(0.3), blurRadius: 12, spreadRadius: 2)]
                                        : null,
                                  ),
                                  child: Center(
                                    child: Text(
                                      '$count',
                                      style: TextStyle(
                                        color: isSelected ? Colors.amber : Colors.white54,
                                        fontSize: 20,
                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ).animate().fadeIn(delay: 300.ms, duration: 600.ms),

                  const SizedBox(height: 25),

                  // Action Button or Loading
                  // --- Progressive Image Generation ---
                  if (controller.isGeneratingImages) ...[
                    // Show images appearing one by one
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: Colors.amberAccent.withOpacity(0.5)),
                      ),
                      child: Column(
                        children: [
                          // Progress indicator
                          Text(
                            controller.statusMessage,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 16, fontStyle: FontStyle.italic, color: Colors.amber),
                          ),
                          const SizedBox(height: 16),
                          // Progress bar
                          LinearProgressIndicator(
                            value: controller.generatedImageUrls.length / controller.totalScenes,
                            backgroundColor: Colors.white12,
                            valueColor: const AlwaysStoppedAnimation<Color>(Colors.amber),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${controller.generatedImageUrls.length} / ${controller.totalScenes} scenes painted',
                            style: const TextStyle(color: Colors.white54, fontSize: 12),
                          ),
                          const SizedBox(height: 20),
                          // Grid of generated images
                          if (controller.generatedImageUrls.isNotEmpty) ...[
                            SizedBox(
                              height: 200,
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                itemCount: controller.totalScenes,
                                itemBuilder: (context, index) {
                                  final isGenerated = index < controller.generatedImageUrls.length;
                                  final isGenerating = index == controller.generatedImageUrls.length;

                                  return Container(
                                    width: 150,
                                    margin: const EdgeInsets.only(right: 12),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: isGenerating ? Colors.amber : Colors.white24,
                                        width: isGenerating ? 2 : 1,
                                      ),
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(11),
                                      child: isGenerated
                                          ? Image.network(
                                              controller.generatedImageUrls[index],
                                              fit: BoxFit.cover,
                                            ).animate().fadeIn(duration: 600.ms).scale(begin: const Offset(0.8, 0.8))
                                          : Container(
                                              color: Colors.black38,
                                              child: Center(
                                                child: isGenerating
                                                    ? const CircularProgressIndicator(color: Colors.amber, strokeWidth: 2)
                                                    : Icon(Icons.image_outlined, color: Colors.white24, size: 40),
                                              ),
                                            ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ] else if (controller.isProcessing) ...[
                    const CircularProgressIndicator(color: Colors.amber),
                    const SizedBox(height: 20),
                    Text(
                      controller.statusMessage,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16, fontStyle: FontStyle.italic),
                    ).animate(onPlay: (c) => c.repeat()).fade(),

                  // --- Story Text Approval Step ---
                  ] else if (controller.isStoryReady && controller.storyData != null) ...[
                     Container(
                       height: 300,
                       decoration: BoxDecoration(
                         color: Colors.black54,
                         borderRadius: BorderRadius.circular(15),
                         border: Border.all(color: Colors.amberAccent.withOpacity(0.5)),
                       ),
                       child: ListView.builder(
                         padding: const EdgeInsets.all(16),
                         itemCount: (controller.storyData!['scenes'] as List).length,
                         itemBuilder: (context, index) {
                           final scene = (controller.storyData!['scenes'] as List)[index];
                           return Padding(
                             padding: const EdgeInsets.only(bottom: 16.0),
                             child: Column(
                               crossAxisAlignment: CrossAxisAlignment.start,
                               children: [
                                 Text('Scene ${index + 1}', style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
                                 const SizedBox(height: 4),
                                 Text(scene['text'] ?? '', style: const TextStyle(color: Colors.white, fontSize: 16, height: 1.4)),
                               ],
                             ),
                           );
                         },
                       ),
                     ),
                     const SizedBox(height: 20),
                     const Text('Read the legend carefully...', style: TextStyle(color: Colors.white70)),
                     const SizedBox(height: 20),
                     ElevatedButton.icon(
                        // Moving to next step: Generate Images
                        onPressed: () => controller.generateImagesFromStory(_imageFile!),
                        icon: const Icon(Icons.palette),
                        label: const Text('Looks Good! Paint it!'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amber,
                          foregroundColor: Colors.black87,
                          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                        ),
                     ),

                  // --- Image Approval Step ---
                  ] else if (controller.areImagesReady) ...[
                     SizedBox(
                       height: 300,
                       child: PageView.builder(
                         itemCount: controller.generatedImageUrls.length,
                         itemBuilder: (context, index) {
                           return Card(
                             color: Colors.black54,
                             child: Column(
                               children: [
                                 Expanded(
                                   child: Image.network(
                                     controller.generatedImageUrls[index],
                                     fit: BoxFit.cover,
                                     loadingBuilder: (c, child, progress) {
                                       if (progress == null) return child;
                                       return const Center(child: CircularProgressIndicator());
                                     },
                                   ),
                                 ),
                                 Padding(
                                   padding: const EdgeInsets.all(8.0),
                                   child: Text('Scene ${index + 1}', style: const TextStyle(color: Colors.amber)),
                                 ),
                               ],
                             ),
                           );
                         },
                       ),
                     ),
                     const SizedBox(height: 20),
                     const Text('Review your scenes before animating!', style: TextStyle(color: Colors.white70)),
                     const SizedBox(height: 20),
                     ElevatedButton.icon(
                        onPressed: () => controller.generateVideosFromImages(),
                        icon: const Icon(Icons.movie_creation),
                        label: const Text('Animate These Scenes!'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amber,
                          foregroundColor: Colors.black87,
                          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                        ),
                     ),

                  ] else if (controller.hasVideos) ...[
                     // Final merged video
                     Container(
                       decoration: BoxDecoration(
                         borderRadius: BorderRadius.circular(15),
                         border: Border.all(color: Colors.amberAccent, width: 2),
                         boxShadow: [
                           BoxShadow(color: Colors.amber.withOpacity(0.3), blurRadius: 20, spreadRadius: 2),
                         ],
                       ),
                       child: ClipRRect(
                         borderRadius: BorderRadius.circular(13),
                         child: SizedBox(
                           height: 350,
                           child: _FinalVideoPlayer(videoPath: controller.finalVideoPath!),
                         ),
                       ),
                     ).animate().fadeIn(duration: 800.ms).scale(begin: const Offset(0.95, 0.95)),
                     const SizedBox(height: 20),
                     Text(
                       '✨ Your Fairy Tale is Complete! ✨',
                       style: TextStyle(
                         color: Colors.amberAccent,
                         fontSize: 18,
                         fontWeight: FontWeight.bold,
                       ),
                     ).animate().shimmer(duration: 2000.ms),
                     const SizedBox(height: 20),
                     ElevatedButton.icon(
                      onPressed: () {
                         setState(() {
                           _imageFile = null;
                           _promptController.clear();
                           controller.reset();
                         });
                      },
                      icon: const Icon(Icons.auto_awesome),
                      label: const Text('Create Another Tale'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber,
                        foregroundColor: Colors.black87,
                        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                      ),
                     ),
                  ] else ...[
                     ElevatedButton(
                       onPressed: () => controller.generateStoryOnly(_promptController.text, _imageFile!, sceneCount: _sceneCount),
                       style: ElevatedButton.styleFrom(
                         padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                         backgroundColor: Colors.amber,
                         foregroundColor: Colors.black87,
                         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                       ),
                       child: const Text('Weave Magic', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                     ).animate().shimmer(delay: 2000.ms, duration: 1500.ms),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black87,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Colors.amber),
              title: const Text('Camera', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.amber),
              title: const Text('Gallery', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Powerful video player using media_kit (libmpv based)
class _FinalVideoPlayer extends StatefulWidget {
  final String videoPath;

  const _FinalVideoPlayer({required this.videoPath});

  @override
  State<_FinalVideoPlayer> createState() => _FinalVideoPlayerState();
}

class _FinalVideoPlayerState extends State<_FinalVideoPlayer> {
  late final Player _player;
  late final VideoController _controller;

  @override
  void initState() {
    super.initState();
    _player = Player();
    _controller = VideoController(_player);

    // Open the video
    final media = kIsWeb
        ? Media(widget.videoPath)
        : Media('file://${widget.videoPath}');

    _player.open(media);
    _player.setPlaylistMode(PlaylistMode.loop); // Loop the fairy tale
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData.dark().copyWith(
        colorScheme: const ColorScheme.dark(
          primary: Colors.amber,
          secondary: Colors.amberAccent,
        ),
      ),
      child: Video(
        controller: _controller,
        controls: AdaptiveVideoControls,
        fill: Colors.black,
      ),
    );
  }
}
