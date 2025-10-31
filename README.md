# SmartChef

A Flutter recipe app with AI-powered recipe generation using Google Gemini API.

## Features

- AI-powered recipe generation from ingredients
- Recipe chat assistant for modifications
- Food identification from images
- Firebase authentication and storage
- Recipe search and discovery

## Setup

### Prerequisites

- Flutter SDK (>=3.4.0)
- Firebase project configured
- Google Gemini API key

### Installation

1. Clone the repository:
```bash
git clone https://github.com/YOUR_USERNAME/smartchef.git
cd smartchef
```

2. Install dependencies:
```bash
flutter pub get
```

3. Set up environment variables:
```bash
cp .env.example .env
```

Edit `.env` and add your API keys:
- `GEMINI_API_KEY`: Get from [Google AI Studio](https://makersuite.google.com/app/apikey)
- Firebase API keys: Get from your Firebase Console under Project Settings

4. Set up Firebase configuration files:
   - Copy `android/app/google-services.json.example` to `android/app/google-services.json` and add your Firebase config
   - Copy `ios/Runner/GoogleService-Info.plist.example` to `ios/Runner/GoogleService-Info.plist` and add your Firebase config
   - Copy `macos/Runner/GoogleService-Info.plist.example` to `macos/Runner/GoogleService-Info.plist` and add your Firebase config

You can download these files from your Firebase Console project settings.

5. Run the app:
```bash
flutter run
```

## Security Notes

- Never commit `.env` file or Firebase configuration files
- All API keys should be stored in environment variables
- Template files (`.example`) are safe to commit
