import 'package:flutter/material.dart';

import 'package:camera/camera.dart';

import 'package:data_collector2/presentation/screens/first_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final cameras = await availableCameras();

  final frontCam = cameras[1];
  runApp(MyApp(camera: frontCam,));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, required this.camera});
  final CameraDescription camera;
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home:  FirstPage(camera: camera)
    );
  }
}