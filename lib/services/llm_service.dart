import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class LLMService {
  String get _apiKey => dotenv.env['OPENROUTER_KEY'] ?? '';

  Future<Map<String, dynamic>> generateStory(String userPrompt) async {
    // REAL MODE: Using Free Gemini Flash via OpenRouter
    final uri = Uri.parse('https://openrouter.ai/api/v1/chat/completions');
    
    final prompt = '''
      You are a magical storyteller. 
      Create a short 2-scene fairy tale based on this user idea: "$userPrompt".
      
      Return valid JSON ONLY. No markdown formatting. Structure:
      {
        "scenes": [
          {
            "text": "Story text for scene 1...",
            "image_prompt": "Visual description of scene 1, fairy tale style...",
            "video_prompt": "Action description for scene 1..."
          },
          {
            "text": "Story text for scene 2...",
            "image_prompt": "Visual description of scene 2, fairy tale style...",
            "video_prompt": "Action description for scene 2..."
          }
        ]
      }
    ''';

    try {
      final response = await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer $_apiKey',
          'Content-Type': 'application/json',
          'HTTP-Referer': 'https://github.com/flutter/flutter', // Optional, appropriate for open source
          'X-Title': 'Fairy Tale Generator', // Optional
        },
        body: jsonEncode({
          "model": "deepseek/deepseek-r1:free",
          "messages": [
            {"role": "user", "content": prompt}
          ],
          "temperature": 0.7,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final content = data['choices'][0]['message']['content'];
        
        // Clean string (remove markdown json blocks)
        final cleanContent = content.replaceAll('```json', '').replaceAll('```', '').trim();
        return jsonDecode(cleanContent);
      } else {
        throw Exception('Failed to generate story: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('LLM Service Error: $e');
    }
  }
}
