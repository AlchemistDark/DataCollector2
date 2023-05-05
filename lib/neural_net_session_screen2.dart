import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:camera/camera.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:image/image.dart' as img;

import 'package:data_collector2/background.dart';
import 'package:data_collector2/neural_net_session_controller.dart';
import 'package:data_collector2/position_controller.dart';
import 'package:data_collector2/position_marker_widget.dart';
import 'package:data_collector2/session_class.dart';

/// Экран сессии для теста взаимодействия с нейросетью.

class NeuralNetSessionScreen extends StatefulWidget {

  final NeuralNetSessionController controller;
  final NeuralNetSession session;
  final List<List<int>> list;

  const NeuralNetSessionScreen({
    required this.controller,
    required this.session,
    required this.list,
    Key? key
  }) : super(key: key);

  @override
  State<NeuralNetSessionScreen> createState() => _NeuralNetSessionScreen();
}

class _NeuralNetSessionScreen extends State<NeuralNetSessionScreen> {
  @override
  Widget build(BuildContext context) {
    //return Text("dgshjhdgsfdas");

    return StreamBuilder<ScreenState>(
      initialData: widget.controller.screenState,
      stream: widget.controller.positionStateCtrl.stream,
      builder: (context, snapshot) {
        ScreenState state = snapshot.data!;
        // double leftPudding = pageController.focusMarkerPaddingList[state.frameNumber][0];
        // double topPudding = pageController.focusMarkerPaddingList[state.frameNumber][1];
        // bool isStop = state.isStop;
        return Scaffold(
            body: Column(
              children: [
                Flexible(
                  child: Text(
                      "${state.tilt}" //state.log
                  )
                ),
                if (state.lastPhoto != null)
                  Image.memory(state.lastPhoto!)
              ],
            )
        );
      }
    );
  }
}


