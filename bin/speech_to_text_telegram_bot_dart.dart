// ignore_for_file: unnecessary_brace_in_string_interps

import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:telegram_client/telegram_client.dart';
import 'package:alfred/alfred.dart';
import 'package:galaxeus_lib/galaxeus_lib.dart';
import 'package:path/path.dart' as p;

import 'package:whisper_dart/whisper_dart.dart';
import 'package:ffmpeg_dart/ffmpeg_dart.dart';
 
void main(List<String> arguments) async { 
  Args args = Args(arguments);

  Directory current_dir = Directory.current;
  String db_bot_api = p.join(current_dir.path, "bot_api");
  Directory dir_bot_api = Directory(db_bot_api);
  if (!dir_bot_api.existsSync()) {
    dir_bot_api.createSync(recursive: true);
  }
  int PORT = int.parse(Platform.environment["PORT"] ?? "8080");
  String HOST = Platform.environment["HOST"] ?? "0.0.0.0";

  String token_bot = args["--token_bot"] ?? "";
  TelegramBotApiServer telegramBotApiServer = TelegramBotApiServer();
  telegramBotApiServer.run(
    executable: "telegram-bot-api",
    arguments: telegramBotApiServer.optionsParameters(
      api_id: args["--api_id"] ?? "",
      api_hash: args["--api_hash"] ?? "",
      http_port: "9000",
      dir: dir_bot_api.path,
    ),
  );
  TelegramBotApi tg = TelegramBotApi(token_bot, clientOption: {
    "api": "http://0.0.0.0:9000/",
  });

  tg.request("setWebhook", parameters: {"url": "http://${HOST}:${PORT}"});
  Alfred app = Alfred(
    logLevel: LogType.error,
  );
  EventEmitter eventEmitter = EventEmitter();

  ReceivePort receivePort = ReceivePort();

  ReceivePort secondReceivePort = ReceivePort();
  receivePort.listen((message) {
    if (message is WhisperResponse) {
      print(message.toString());
    }
  });
  Isolate.spawn(
    (WhisperIsolateData whisperIsolateData) {
      Whisper whisper = Whisper(
        whisperLib: p.join(
          Directory.current.path,
          "whisper_dart",
          "whisper.so",
        ),
      );
      ReceivePort receivePort = ReceivePort();
      whisperIsolateData.second_send_port.send(receivePort.sendPort);
      receivePort.listen((message) async {
        if (message is WhisperData) {
          Directory directory = Directory(p.join(Directory.current.path, "temp"));
          if (!directory.existsSync()) {
            await directory.create(recursive: true);
          }
          File file = File(p.join(directory.path, "${DateTime.now().millisecondsSinceEpoch}.wav"));
          if (file.existsSync()) {
            await file.delete(recursive: true);
          }

          var res = whisper.request(
            whisperLib: p.join(
              Directory.current.path,
              "whisper_dart",
              "whisper.so",
            ),
            whisperRequest: WhisperRequest.fromWavFile(
              // audio: File(message.audio),

              audio: WhisperAudioconvert.convert(
                audioInput: File(message.audio),
                audioOutput: File(file.path),
              ),
              model: File(p.join(
                Directory.current.path,
                "whisper_dart",
                "whisper.bin",
              )),
            ),
          );
          await tg.request("sendMessage", parameters: {
            "chat_id": message.chat_id,
            "text": res.text ?? "Failed",
          });
          return;
        } else {
          whisperIsolateData.main_send_port.send("else");
        }
      });
    },
    WhisperIsolateData(
      main_send_port: receivePort.sendPort,
      second_send_port: secondReceivePort.sendPort,
    ),
  );

  final port = secondReceivePort.asBroadcastStream();
  final send_port = await port.first;
  if (send_port is SendPort) {
    eventEmitter.on("update", null, (ev, context) {
      if (ev.eventData is WhisperData) {
        send_port.send((ev.eventData as WhisperData));
      }
    });
  }

  eventEmitter.on("update", null, (ev, context) async {
    if (ev.eventData is Map) {
      Map update = (ev.eventData as Map);

      if (update["message"] is Map) {
        Map msg = (update["message"] as Map);
        Map from = msg["from"];
        int from_id = from["id"];
        Map chat = msg["chat"];
        int chat_id = chat["id"];
        String? text = msg["text"];
        Map? voice = msg["voice"];
        if (text != null) {
          if (RegExp(r"/start", caseSensitive: false).hasMatch(text)) {
            await tg.request("sendMessage", parameters: {
              "chat_id": chat_id,
              "text": "Hai manies lagi apah nich, btw perkenalkan aku robot yah manies, di buat dari cingtah oppah @azkadev",
              "reply_markup": {
                "inline_keyboard": [
                  [
                    {"text": "Github", "url": "https://github.com/azkadev"}
                  ]
                ]
              }
            });
            return;
          }
          await tg.request("sendMessage", parameters: {
            "chat_id": chat_id,
            "text": text,
            "reply_markup": {
              "inline_keyboard": [
                [
                  {"text": "Github", "url": "https://github.com/azkadev"}
                ]
              ]
            }
          });
          return;
        }
        if (voice != null && voice["file_id"] is String) {
          String voice_file_id = voice["file_id"];
          var res = await tg.request("getFile", parameters: {"file_id": voice_file_id});
// {
//     "ok": true,
//     "result": {
//         "file_id": "AwACAgUAAxkBAAMPY45KAXgyPy-uFxAJYjitHFYQrgYAAoAGAAIW5XlU_zsVWbT1noQpBA",
//         "file_unique_id": "AgADgAYAAhbleVQ",
//         "file_size": 507,
//         "file_path": /pathh/voice/file_0.oga",
//         "file_url": "pathcile_0.oga"
//     }
// }
          late String message_text = "Failed Tolong Ulangin Lagi ya";
          if (res["ok"] == true && res["result"] is Map && res["result"]["file_path"] is String) {
            message_text = "Transcribe....";
            String voice_file_path = res["result"]["file_path"];
            eventEmitter.emit(
              "update",
              null,
              WhisperData(
                chat_id: chat_id,
                audio: voice_file_path,
              ),
            );
          }

          await tg.request("sendMessage", parameters: {
            "chat_id": chat_id,
            "text": message_text,
          });
          return;
        }
      }
    }
  });

  app.all("/", (req, res) async {
    if (req.method.toLowerCase() != "post") {
      return res.json({"@type": "ok", "message": "server run normal"});
    } else {
      Map body = await req.bodyAsJsonMap;
      eventEmitter.emit("update", null, body);
      return res.json({"@type": "ok", "message": "server run normal"});
    }
  });

  await app.listen(PORT, HOST);

  print("Server run on ${app.server!.address.address}}");
}

class WhisperData {
  late String audio;
  late int chat_id;
  WhisperData({
    required this.chat_id,
    required this.audio,
  });
}

class WhisperIsolateData {
  final SendPort main_send_port;
  final SendPort second_send_port;
  WhisperIsolateData({
    required this.main_send_port,
    required this.second_send_port,
  });
}
