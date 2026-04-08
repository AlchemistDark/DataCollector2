import 'package:flutter/material.dart';

import 'package:data_collector2/presentation/widgets/background.dart';
import 'package:data_collector2/presentation/controllers/neural_net_session_controller.dart';
import 'package:data_collector2/presentation/widgets/position_marker_widget.dart';
import 'package:data_collector2/domain/entities/session_class.dart';

/// The main session screen where the gaze tracking experiment takes place.
/// 
/// It integrates the [EyeTrackerScreen] for the focus sequence and 
/// the [PositionMarkerScreen] for real-time smartphone positioning feedback.
class NeuralNetSessionScreen extends StatelessWidget {
  /// The controller orchestrating state and camera logic.
  final NeuralNetSessionController controller;
  
  /// The data model for the current collection session.
  final NeuralNetSession session;
  
  /// The randomized list of coordinate pairs for the experiment path.
  final List<List<int>> list;

  /// Creates a [NeuralNetSessionScreen].
  const NeuralNetSessionScreen({
    required this.controller,
    required this.session,
    required this.list,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final double mainWidth = MediaQuery.of(context).size.width;
    final double areaWidth = mainWidth - 24; // Two 12px margins
    final double areaHeight = areaWidth * 1.5;
    final double backgroundPictureSize = areaWidth / 2;
    const double focusMarkerSize = 20;

    // Generate the path animation coordinate list.
    final List<List<double>> focusMarkerPaddingList = controller.getFocusMarkerPaddingList(
      backgroundPictureSize,
      focusMarkerSize,
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
                focusMarkerSize: focusMarkerSize,
              ),
            ),
          ),
          Expanded(
            child: SizedBox(
              width: areaWidth,
              child: Center(
                child: PositionMarkerScreen(controller),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Widget responsible for drawing the gaze tracking focus marker animation.
class EyeTrackerScreen extends StatefulWidget {
  /// The session controller.
  final NeuralNetSessionController controller;
  
  /// Current session metadata.
  final NeuralNetSession session;
  
  /// Total width allocated for the focus area.
  final double areaWidth;
  
  /// Total height allocated for the focus area.
  final double areaHeight;
  
  /// Precalculated sequence of [x, y, capture] values.
  final List<List<double>> focusMarkerPaddingList;
  
  /// Size of the circular focus marker.
  final double focusMarkerSize;

  /// Creates an [EyeTrackerScreen].
  const EyeTrackerScreen({
    required this.session,
    required this.controller,
    required this.areaWidth,
    required this.areaHeight,
    required this.focusMarkerPaddingList,
    required this.focusMarkerSize,
    super.key,
  });

  @override
  State<EyeTrackerScreen> createState() => _EyeTrackerScreenState();
}

class _EyeTrackerScreenState extends State<EyeTrackerScreen> {
  @override
  Widget build(BuildContext context) {
    // Start the tracker logic immediately upon widget mounting.
    widget.controller.startEyeTracker(widget.focusMarkerPaddingList);

    return StreamBuilder<EyeTrackerState>(
      initialData: widget.controller.eyeTrackerState,
      stream: widget.controller.eyeTrackerCtrl.stream,
      builder: (context, snapshot) {
        final EyeTrackerState state = snapshot.data!;
        final double leftPadding = widget.focusMarkerPaddingList[state.frameNumber][0];
        final double topPadding = widget.focusMarkerPaddingList[state.frameNumber][1];

        return Stack(
          children: [
            // Background collection pattern if enabled
            if (widget.session.showBackground!)
              Background(
                areaWidth: widget.areaWidth,
                areaHeight: widget.areaHeight,
              )
            else
              Container(
                width: widget.areaWidth,
                height: widget.areaHeight,
                color: Colors.transparent,
              ),

            // The animated focus marker
            Padding(
              padding: EdgeInsets.only(
                left: leftPadding,
                top: topPadding,
              ),
              child: SizedBox(
                width: widget.focusMarkerSize,
                height: widget.focusMarkerSize,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(widget.focusMarkerSize / 2),
                    color: Colors.black,
                  ),
                ),
              ),
            ),

            // Completion overlay
            if (state.isAppStop)
              Center(
                child: Container(
                  alignment: Alignment.center,
                  height: MediaQuery.of(context).size.height / 2,
                  width: MediaQuery.of(context).size.width / 2,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Text(
                    'Конец!',
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Widget providing visual feedback for smartphone spatial orientation.
class PositionMarkerScreen extends StatefulWidget {
  /// The session controller providing position stream.
  final NeuralNetSessionController controller;

  /// Creates a [PositionMarkerScreen].
  const PositionMarkerScreen(this.controller, {super.key});

  @override
  State<PositionMarkerScreen> createState() => _PositionMarkerScreenState();
}

class _PositionMarkerScreenState extends State<PositionMarkerScreen> {
  @override
  Widget build(BuildContext context) {
    // Start the real-time position analysis loop.
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