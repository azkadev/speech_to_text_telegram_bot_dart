# Speech To Text Telegram Bot Dart 

Telegram Speech to Text Bot Menggunakan library [Whisper-Dart](https://github.com/azkadev/whisper_dart) Full Offline Unlimited Transcribe without any api key

https://user-images.githubusercontent.com/82513502/205732223-1b624a0c-3e03-4621-9a88-daeabbc1381e.mp4

## Cara run

1. CLone dlu

```bash
git clone https://github.com/azkadev/speech_to_text_telegram_bot_dart
cd speech_to_text_telegram_bot_dart
```

2. download package dahulu

```bash
dart pub get
```

3. Download model dan compile whisper_cpp [Whisper-Dart](https://github.com/azkadev/whisper_dart) 

4. run 

```bash
dart run bin/speech_to_text_telegram_bot_dart.dart  --token_bot="token" --api_id="telegram_api_id" --api_hash="telegram_api_hash"
```