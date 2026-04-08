import 'package:flutter/material.dart';

import 'package:data_collector2/presentation/controllers/neural_net_session_controller.dart';


class PositionIndicator extends StatefulWidget {

  final NeuralNetSessionController controller;
  final Color gradientBorderColor1;
  final Color gradientBorderColor2;
  final Color gradientFillColor1;
  final Color gradientFillColor2;
  final Color separatorColor;
  final double width;
  final double height;

  const PositionIndicator({
    required this.controller,
    required this.gradientBorderColor1,
    required this.gradientBorderColor2,
    required this.gradientFillColor1,
    required this.gradientFillColor2,
    required this.separatorColor,
    required this.width,
    required this.height,
    super.key,
  });

  @override
  State<PositionIndicator> createState() => _PositionIndicatorState();

}

class _PositionIndicatorState extends State<PositionIndicator> {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<PositionMarkerState>(
      initialData: widget.controller.positionMarkerState,
      stream: widget.controller.positionMarkerStream,
      builder: (context, snapshot) {
        PositionMarkerState position = snapshot.data!;
        double markerSize = 13 + 4 * position.distance;
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              children: [
                PositionIndicatorBase(
                  gradientBorderColor1: widget.gradientBorderColor1,
                  gradientBorderColor2: widget.gradientBorderColor2,
                  gradientFillColor1: widget.gradientFillColor1,
                  gradientFillColor2: widget.gradientFillColor2,
                  separatorColor: widget.separatorColor,
                  width: widget.width,
                  height: widget.height,
                ),
                Container(
                  padding: EdgeInsets.only(
                    top: ((53 - markerSize + (49 - markerSize) * position.height) / 2),
                    left: (26 - markerSize) / 2
                  ),
                  child: PositionIndicatorMarker(markerSize, position.distance)
                )
              ]
            ),
            Text('позиция ${position.height} ${position.distance}')
          ]
        );
      }
    );
  }
}

class PositionIndicatorBase extends StatelessWidget {

  final Color gradientBorderColor1;
  final Color gradientBorderColor2;
  final Color gradientFillColor1;
  final Color gradientFillColor2;
  final Color separatorColor;
  final double width;
  final double height;

  const PositionIndicatorBase({
    required this.gradientBorderColor1,
    required this.gradientBorderColor2,
    required this.gradientFillColor1,
    required this.gradientFillColor2,
    required this.separatorColor,
    required this.width,
    required this.height,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [gradientBorderColor1, gradientBorderColor2]
          ),
          borderRadius: BorderRadius.circular(width / 2),
        ),
        child: Center(
          child: Container(
            width: width - 4,
            height: height - 4,
            padding: const EdgeInsets.only(top: 2, bottom: 2),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: [gradientFillColor1, gradientFillColor2]
              ),
              borderRadius: BorderRadius.circular((width - 4) / 2),
            ),
            child: Column(
              children: [
                Expanded(
                  flex: 1,
                  child: SizedBox(
                    width: width / 13 * 8
                  ),
                ),
                Container(
                  width: width / 13 * 8,
                  height: height / 53,
                  color: separatorColor,
                ),
                SizedBox(
                  height: height / 53 * 20,
                  width: width / 13 * 8
                ),
                Container(
                  width: width / 13 * 8,
                  height: height / 53,
                  color: separatorColor,
                ),
                Expanded(
                  flex: 1,
                  child: SizedBox(
                    width: width / 13 * 8
                  ),
                )
              ],
            ),
          )
        )
      )
    );
  }
}

class PositionIndicatorMarker extends StatelessWidget{

  final double size;
  final double colorTintFactor;

  late final Color gradientCenterColor;
  late final int gradientCenterRedChannel;
  late final int gradientCenterGreenChannel;
  late final int gradientCenterBlueChannel;
  late final Color gradientBorderColor;
  late final int gradientBorderRedChannel;
  late final int gradientBorderGreenChannel;
  late final int gradientBorderBlueChannel;

  PositionIndicatorMarker(this.size, this.colorTintFactor, {super.key}) {
    gradientCenterRedChannel = 167 + (88 * (colorTintFactor).abs()).round();
    gradientCenterGreenChannel = 255 - (88 * (colorTintFactor).abs()).round();
    gradientCenterBlueChannel = 167;
    gradientCenterColor = Color.fromARGB(
      255,
      gradientCenterRedChannel,
      gradientCenterGreenChannel,
      gradientCenterBlueChannel
    );
    gradientBorderRedChannel = (167.0 * (colorTintFactor).abs()).round();
    gradientBorderGreenChannel = 167 - gradientBorderRedChannel;
    gradientBorderBlueChannel = 0;
    gradientBorderColor = Color.fromARGB(
      255,
      gradientBorderRedChannel,
      gradientBorderGreenChannel,
      gradientBorderBlueChannel
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(size / 2),
          gradient: RadialGradient(
            colors: [gradientCenterColor, gradientBorderColor]
          )
        )
      )
    );
  }
}