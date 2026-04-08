import 'package:flutter/material.dart';

import 'package:data_collector2/presentation/controllers/neural_net_session_controller.dart';

/// A widget that visualizes the smartphone's sensed position in real-time.
/// 
/// It displays a graphical indicator (base and marker) that moves and scales 
/// based on the [height] and [distance] values received from the server.
class PositionIndicator extends StatefulWidget {
  /// The controller providing the position data stream.
  final NeuralNetSessionController controller;
  
  /// Outer gradient color 1 for the base.
  final Color gradientBorderColor1;
  
  /// Outer gradient color 2 for the base.
  final Color gradientBorderColor2;
  
  /// Inner fill gradient color 1 for the base.
  final Color gradientFillColor1;
  
  /// Inner fill gradient color 2 for the base.
  final Color gradientFillColor2;
  
  /// Color used for the horizontal separator lines.
  final Color separatorColor;
  
  /// Total width of the indicator widget.
  final double width;
  
  /// Total height of the indicator widget.
  final double height;

  /// Creates a [PositionIndicator] with the specified styling and [controller].
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
        final PositionMarkerState position = snapshot.data!;
        
        // Scale the marker size based on the distance from the user's face.
        final double markerSize = 13 + 4 * position.distance;
        
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              children: [
                // Draw the static container with gradients and separators.
                PositionIndicatorBase(
                  gradientBorderColor1: widget.gradientBorderColor1,
                  gradientBorderColor2: widget.gradientBorderColor2,
                  gradientFillColor1: widget.gradientFillColor1,
                  gradientFillColor2: widget.gradientFillColor2,
                  separatorColor: widget.separatorColor,
                  width: widget.width,
                  height: widget.height,
                ),
                // Draw the dynamic marker positioned based on height and distance.
                Container(
                  padding: EdgeInsets.only(
                    top: ((53 - markerSize + (49 - markerSize) * position.height) / 2),
                    left: (26 - markerSize) / 2,
                  ),
                  child: PositionIndicatorMarker(markerSize, position.distance),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'позиция: ${position.height.toStringAsFixed(2)} / ${position.distance.toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 12),
            ),
          ],
        );
      },
    );
  }
}

/// The static background part of the position indicator.
/// 
/// Includes the gradient border, fill, and horizontal separator bars.
class PositionIndicatorBase extends StatelessWidget {
  final Color gradientBorderColor1;
  final Color gradientBorderColor2;
  final Color gradientFillColor1;
  final Color gradientFillColor2;
  final Color separatorColor;
  final double width;
  final double height;

  /// Creates static base UI for the position indicator.
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
            colors: [gradientBorderColor1, gradientBorderColor2],
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
                colors: [gradientFillColor1, gradientFillColor2],
              ),
              borderRadius: BorderRadius.circular((width - 4) / 2),
            ),
            child: Column(
              children: [
                const Expanded(flex: 1, child: SizedBox()),
                // Top separator
                Container(
                  width: width / 13 * 8,
                  height: height / 53,
                  color: separatorColor,
                ),
                SizedBox(
                  height: height / 53 * 20,
                  width: width / 13 * 8,
                ),
                // Bottom separator
                Container(
                  width: width / 13 * 8,
                  height: height / 53,
                  color: separatorColor,
                ),
                const Expanded(flex: 1, child: SizedBox()),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The animated marker representing the smartphone's actual position.
/// 
/// It changes its color tint dynamically based on the [colorTintFactor].
class PositionIndicatorMarker extends StatelessWidget {
  /// Diameter of the marker.
  final double size;
  
  /// Factor used to interpolate the marker's color (red to green).
  final double colorTintFactor;

  /// Calculated colors for the marker's gradient.
  late final Color gradientCenterColor;
  late final Color gradientBorderColor;

  /// Creates a marker and calculates its color channels based on the tint factor.
  PositionIndicatorMarker(this.size, this.colorTintFactor, {super.key}) {
    // Red channel increases as tint factor absolute value increases.
    final int gradientCenterRedChannel = 167 + (88 * (colorTintFactor).abs()).round();
    // Green channel decreases as tint factor absolute value increases.
    final int gradientCenterGreenChannel = 255 - (88 * (colorTintFactor).abs()).round();
    const int gradientCenterBlueChannel = 167;
    
    gradientCenterColor = Color.fromARGB(
      255,
      gradientCenterRedChannel.clamp(0, 255),
      gradientCenterGreenChannel.clamp(0, 255),
      gradientCenterBlueChannel,
    );

    final int gradientBorderRedChannel = (167.0 * (colorTintFactor).abs()).round();
    final int gradientBorderGreenChannel = 167 - gradientBorderRedChannel;
    
    gradientBorderColor = Color.fromARGB(
      255,
      gradientBorderRedChannel.clamp(0, 255),
      gradientBorderGreenChannel.clamp(0, 255),
      0,
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
            colors: [gradientCenterColor, gradientBorderColor],
          ),
        ),
      ),
    );
  }
}