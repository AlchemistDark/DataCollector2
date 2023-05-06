import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:data_collector2/background.dart';
import 'package:data_collector2/neural_net_session_controller.dart';
import 'package:data_collector2/position_marker_widget.dart';
import 'package:data_collector2/session_class.dart';

/// Экран сессии для теста взаимодействия с нейросетью.

class NeuralNetSessionScreen extends StatelessWidget {

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
  Widget build(BuildContext context){
    final double mainWidth = MediaQuery.of(context).size.width;
    final double areaWidth = mainWidth - 24; // two indents of 12 px.
    final double areaHeight = areaWidth * 1.5;
    final double backgroundPictureSize = areaWidth / 2;
    const double focusMarkerSize = 20;
    final List<List<double>> focusMarkerPaddingList
        = controller.getFocusMarkerPaddingList(
          backgroundPictureSize,
          focusMarkerSize
        );
    return Scaffold(
      body: Column(
        children: [
          Container(
            width: areaWidth,
            height: areaHeight,
            margin: const EdgeInsets.only(left: 12.0, top: 55.0, right: 12.0),
            child: Center(
              child: EyeTrackerScreen(
                session: session,
                controller: controller,
                areaWidth: areaWidth,
                areaHeight: areaHeight,
                focusMarkerPaddingList: focusMarkerPaddingList,
                focusMarkerSize: focusMarkerSize
              )
            ),
          ),
          Expanded(
            child: SizedBox(
              width: areaWidth,
              child: Center(
                child: PositionMarkerScreen(controller),
              ),
            )
          )
        ],
      )
    );
  }

}

/// Класс виджета глазного трекера.
class EyeTrackerScreen extends StatefulWidget {

  final NeuralNetSessionController controller;
  final NeuralNetSession session;
  final double areaWidth;
  final double areaHeight;
  final List<List<double>> focusMarkerPaddingList;
  final double focusMarkerSize;

  const EyeTrackerScreen({
    required this.session,
    required this.controller,
    required this.areaWidth,
    required this.areaHeight,
    required this.focusMarkerPaddingList,
    required this.focusMarkerSize,
    Key? key
  }) : super(key: key);

  @override
  State<EyeTrackerScreen> createState() => _EyeTrackerScreenState();

}

class _EyeTrackerScreenState extends State<EyeTrackerScreen> {

  @override
  Widget build(BuildContext context) {
    widget.controller.startEyeTracker(widget.focusMarkerPaddingList);
    print('Запуск глазного трекера '
        '${DateTime.now().second} ${DateTime.now().millisecond}');
    return StreamBuilder<EyeTrackerState>(
      initialData: widget.controller.eyeTrackerState,
      stream: widget.controller.eyeTrackerCtrl.stream,
      builder: (context, snapshot) {
        EyeTrackerState state = snapshot.data!;
        double leftPudding = widget.focusMarkerPaddingList[state.frameNumber][0];
        double topPudding = widget.focusMarkerPaddingList[state.frameNumber][1];
        return Stack(
          children: [
            if (widget.session.showBackground!)
              Background(
                areaWidth: widget.areaWidth,
                areaHeight: widget.areaHeight
              ),
            if (!widget.session.showBackground!)
              Container(
                width: widget.areaWidth,
                height: widget.areaHeight,
                color: Colors.red.withOpacity(0),
              ),
            Padding(
              padding: EdgeInsets.only(
                left: leftPudding,
                top: topPudding
              ),
              child: SizedBox(
                width: widget.focusMarkerSize,
                height: widget.focusMarkerSize,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(
                      widget.focusMarkerSize / 2
                    ),
                    color: Colors.black
                  ),
                )
              )
            ),
            // if(state.pauseTimer != 0)
            //   Center(
            //     child: Container(
            //       alignment: Alignment.center,
            //       height: MediaQuery.of(context).size.height / 2,
            //       width: MediaQuery.of(context).size.width / 2,
            //       color: Colors.white12.withOpacity(0.5),
            //       child: Text(
            //         '${state.pauseTimer}',
            //         style: TextStyle(fontSize: 30)
            //       ),
            //     )
            //   ),
            if(state.isAppStop)
              Center(
                child: Container(
                  alignment: Alignment.center,
                  height: MediaQuery.of(context).size.height / 2,
                  width: MediaQuery.of(context).size.width / 2,
                  color: Colors.white12.withOpacity(0.5),
                  child: const Text(
                    'Конец!',
                    style: TextStyle(fontSize: 30)
                  )
                )
              )
          ]
        );
      }
    );
  }

}

/// Класс виджета индикатора положения смартфона.
class PositionMarkerScreen extends StatefulWidget {

  final NeuralNetSessionController controller;

  const PositionMarkerScreen(this.controller, {Key? key}) : super(key: key);

  @override
  State<PositionMarkerScreen> createState() => _PositionMarkerScreenState();

}

class _PositionMarkerScreenState extends State<PositionMarkerScreen> {

  @override
  Widget build(BuildContext context) {
    print("Запуск индикатора положения ${DateTime.now().second} ${DateTime.now().millisecond}");
    widget.controller.startPositionMarker();
    return PositionIndicator(
      controller: widget.controller,
      gradientBorderColor1: const Color(0xFF2C2F37),
      gradientBorderColor2: const Color(0xFF3C3E47),
      gradientFillColor1: const Color(0xFF464851),
      gradientFillColor2: const Color(0xFF282B33),
      separatorColor: const Color(0xFF50B498),
      width: 26,
      height: 53,
    );
  }

}