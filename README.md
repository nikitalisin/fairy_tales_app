# ✨ Fairy Tale Generator ✨

A beautiful Flutter application that generates unique fairy tales using AI. 

## 🚀 Features
- **Portrait Magic**: Uses your photo as a reference for character generation.
- **AI Storytelling**: Generates scene-by-scene scripts (currently in manual mode for stability).
- **Asset Generation**:
    - **Images**: Uses [fal.ai](https://fal.ai) (Nano Banana) for style-consistent images.
    - **Video**: Uses [fal.ai](https://fal.ai) (Seedance) to animate scenes.
- **Verification Flow**: 3-step approval process (Text -> Image -> Video).

## 🛠️ Setup
1. **Clone the repository**
2. **Install dependencies**:
   ```bash
   flutter pub get
   ```
3. **Configure API Keys**:
   Create a `.env` file in the root directory and add your keys:
   ```env
   FAL_KEY=your_fal_ai_key
   OPENROUTER_KEY=your_openrouter_key
   ```
4. **Run the app**:
   ```bash
   flutter run
   ```

## 📦 Tech Stack
- **Flutter** (Mobile/iOS)
- **Fal.ai** (Image & Video generative APIs)
- **OpenRouter** (Llama/Mistral/DeepSeek support)
- **Provider** (State Management)
- **Flutter Animate** (Visual Effects)

## 🎨 Design
- **Theme**: Dark magical aesthetic.
- **Typography**: `Cinzel` from Google Fonts for a classic fairy tale feel.
