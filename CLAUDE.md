# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Fairy Tale Generator - A Flutter app that creates AI-generated fairy tales with images and videos from user photos.

## Development Commands

```bash
# Install dependencies
flutter pub get

# Run the app
flutter run

# Run on specific device
flutter run -d chrome    # Web
flutter run -d windows   # Windows
flutter run -d macos     # macOS

# Static analysis
flutter analyze

# Run tests
flutter test

# Run single test file
flutter test test/widget_test.dart

# Build release
flutter build apk       # Android
flutter build ios       # iOS
flutter build web       # Web
```

## Environment Setup

Create `.env` file in root directory:
```env
FAL_KEY=your_fal_ai_key
OPENROUTER_KEY=your_openrouter_key
```

The `.env` file is loaded via `flutter_dotenv` at app startup and must be declared in `pubspec.yaml` assets.

## Architecture

### State Management
Uses **Provider** with `ChangeNotifier` pattern. Single `StoryController` manages all app state and is provided at the root via `MultiProvider`.

### Service Layer
- **FalService** (`lib/services/fal_service.dart`): Handles fal.ai API for image/video generation
  - Image model: `fal-ai/nano-banana/edit`
  - Video model: `fal-ai/bytedance/seedance/v1/lite/image-to-video`
  - Uses queue-based async generation with polling

- **LLMService** (`lib/services/llm_service.dart`): OpenRouter API for story generation
  - Model: `deepseek/deepseek-r1:free`
  - Currently bypassed (manual mode) for stability

### Generation Flow
Three-step verification process with user approval at each stage:
1. **Story Generation**: Creates scene text and prompts (currently manual/hardcoded)
2. **Image Generation**: Polls fal.ai queue until COMPLETED, extracts image URLs
3. **Video Generation**: Animates approved images via fal.ai seedance

### File Structure
```
lib/
├── main.dart                    # App entry, UI, theme (Cinzel font, dark theme)
├── controllers/
│   └── story_controller.dart    # State management, generation orchestration
└── services/
    ├── fal_service.dart         # fal.ai image/video API client
    └── llm_service.dart         # OpenRouter LLM client
```

## Key Implementation Notes

- User photos are converted to base64 data URLs before sending to fal.ai
- fal.ai jobs are polled every 2 seconds with 150 max attempts (5 min timeout)
- Videos are downloaded to app documents directory on mobile, streamed on web
- UI uses `flutter_animate` for visual effects and `chewie` for video playback
