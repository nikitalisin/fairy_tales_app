import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class LLMService {
  String get _apiKey => dotenv.env['OPENROUTER_KEY'] ?? '';

  static const String _systemPrompt = '''You are a master fairy tale writer creating magical stories for an AI video generator.

Your task: Create a fairy tale where the USER'S PHOTO becomes the main character. The number of scenes will be specified in the user message.

CRITICAL RULES FOR IMAGE PROMPTS:
- The AI will use a reference photo of a real person - NEVER describe their face, hair, or body
- Start each image_prompt with: "Same person from reference photo as"
- Describe ONLY: costume, pose, environment, lighting, atmosphere, magical elements
- Style: dreamy fairy tale illustration, soft lighting, magical atmosphere, 4K detailed

CRITICAL RULES FOR VIDEO PROMPTS:
- Seedance AI works best with SUBTLE, SLOW movements
- Good: "gentle breeze moves hair and cape, soft particle effects float by, slight camera push"
- Bad: "running fast, jumping, quick movements" (will look broken)
- Always include: ambient motion (wind, particles, light rays) + subtle character motion + slow camera movement

OUTPUT FORMAT - Return ONLY valid JSON, no markdown:
{"scenes":[{"text":"...","image_prompt":"...","video_prompt":"..."}]}''';

  Future<Map<String, dynamic>> generateStory(String userPrompt, {int sceneCount = 3}) async {
    final uri = Uri.parse('https://openrouter.ai/api/v1/chat/completions');

    final userMessage = '''Create a fairy tale about: "$userPrompt"

Return exactly $sceneCount scenes as JSON. Each scene needs:
- text: 2-3 sentences of magical narration
- image_prompt: Scene description (remember: same person from reference photo, don't describe face/body)
- video_prompt: Subtle motion description for 5-second video clip

JSON only, no explanation:''';

    try {
      debugPrint('LLM: Sending request to OpenRouter...');

      final response = await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer $_apiKey',
          'Content-Type': 'application/json',
          'HTTP-Referer': 'https://fairytale.app',
          'X-Title': 'Fairy Tale Generator',
        },
        body: jsonEncode({
          "model": "google/gemini-2.0-flash-exp:free",
          "messages": [
            {"role": "system", "content": _systemPrompt},
            {"role": "user", "content": userMessage}
          ],
          "temperature": 0.8,
          "max_tokens": 2000,
        }),
      );

      debugPrint('LLM: Response status ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final content = data['choices'][0]['message']['content'] as String;

        debugPrint('LLM: Raw response: $content');

        // Extract JSON from response (handle markdown blocks and extra text)
        final jsonStr = _extractJson(content);
        debugPrint('LLM: Extracted JSON: $jsonStr');

        return jsonDecode(jsonStr);
      } else {
        debugPrint('LLM: Error response: ${response.body}');
        throw Exception('API error ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      debugPrint('LLM: Exception: $e');
      throw Exception('LLM Service Error: $e');
    }
  }

  /// Extracts JSON from LLM response, handling markdown blocks and extra text
  String _extractJson(String content) {
    var cleaned = content.trim();

    // Remove markdown code blocks
    cleaned = cleaned.replaceAll('```json', '').replaceAll('```', '');

    // Find JSON object boundaries
    final startIndex = cleaned.indexOf('{');
    final endIndex = cleaned.lastIndexOf('}');

    if (startIndex == -1 || endIndex == -1 || endIndex <= startIndex) {
      throw Exception('No valid JSON found in response');
    }

    return cleaned.substring(startIndex, endIndex + 1);
  }
}
