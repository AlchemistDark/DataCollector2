import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:data_collector2/presentation/screens/first_screen.dart';

/// The entry point for the DataCollector2 application.
/// 
/// Initializes the Flutter bindings, discovers available cameras 
/// (selecting the front camera by default), and launches the root widget.
void main() async {
  // Ensure that plugin services are initialized before running the app.
  WidgetsFlutterBinding.ensureInitialized();

  // Retrieve the list of cameras available on the device.
  final cameras = await availableCameras();

  // Defaulting to the front-facing camera (typically index 1 on most devices).
  final frontCam = cameras[1];

  runApp(MyApp(camera: frontCam));
}

/// The root application widget.
class MyApp extends StatelessWidget {
  /// The camera description initialized during the main startup sequence.
  final CameraDescription camera;

  /// Creates a [MyApp] instance with the required [camera] description.
  const MyApp({super.key, required this.camera});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DataCollector2',
      theme: ThemeData(
        useMaterial3: true,
        primarySwatch: Colors.teal,
      ),
      // Navigate to the initial setup page.
      home: FirstPage(camera: camera),
    );
  }
}