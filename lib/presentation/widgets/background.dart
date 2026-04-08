import 'package:flutter/material.dart';

/// A widget that draws a checkered background pattern for the focus area.
/// 
/// Used to provide a visual reference or varying luminosity background 
/// behind the gaze focus marker.
class Background extends StatelessWidget {
  /// Total width of the focus area.
  final double areaWidth;
  
  /// Total height of the focus area.
  final double areaHeight;

  /// Creates a [Background] widget with specified dimensions.
  const Background({
    super.key,
    required this.areaWidth,
    required this.areaHeight,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Center(
          child: SizedBox(
            width: areaWidth,
            height: areaHeight,
            child: Column(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(color: Colors.tealAccent),
                      ),
                      Expanded(
                        child: Container(color: Colors.limeAccent),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(color: Colors.limeAccent),
                      ),
                      Expanded(
                        child: Container(color: Colors.tealAccent),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(color: Colors.tealAccent),
                      ),
                      Expanded(
                        child: Container(color: Colors.limeAccent),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: Container(
            color: Colors.green,
          ),
        ),
      ],
    );
  }
}

/// A legacy or alternative screen widget displaying a crosshair marker.
/// 
/// Positioned using a grid-like indexing system.
class TableScreen extends StatelessWidget {
  /// Coordinates/indices for positioning.
  final List<int> indexes;
  
  /// Horizontal spacing between grid units.
  final double xDistance;
  
  /// Vertical spacing between grid units.
  final double yDistance;

  /// Internal calculated scaling values.
  late final int xScale;
  late final int yScale;
  late final double _xDistance;
  late final double _yDistance;

  /// Creates a [TableScreen] and calculates its pixel offsets.
  TableScreen(
    this.indexes,
    this.xDistance,
    this.yDistance,
    {super.key}
  ) {
    xScale = (indexes[0] - 1);
    yScale = (indexes[1] - 1);
    
    switch (xScale) {
      case 0:
        _xDistance = 0;
        break;
      default:
        _xDistance = (xDistance * xScale);
    }
    
    switch (yScale) {
      case 0:
        _yDistance = 0;
        break;
      default:
        _yDistance = (yDistance * yScale);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(left: _xDistance, top: _yDistance),
      child: CustomPaint(
        size: const Size(20, 20),
        painter: CrossPainter(),
      ),
    );
  }
}

/// A custom painter that draws a simple black crosshair.
class CrossPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
      
    // Horizontal line
    canvas.drawLine(
      const Offset(0.0, 10.0),
      const Offset(20.0, 10.0),
      line,
    );
    
    // Vertical line
    canvas.drawLine(
      const Offset(10.0, 0.0),
      const Offset(10.0, 20.0),
      line,
    );
  }

  @override
  bool shouldRepaint(CustomPainter old) {
    return false;
  }
}
