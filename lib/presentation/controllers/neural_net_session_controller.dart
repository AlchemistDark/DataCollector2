import 'dart:async';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';

import 'package:data_collector2/domain/entities/app_constants.dart';
import 'package:data_collector2/domain/entities/session_class.dart';
import 'package:data_collector2/data/services/api_service.dart';
import 'package:data_collector2/data/services/camera_stream_worker.dart';

/// Controller that manages the data collection session and neural network interaction.
/// 
/// It orchestrates the camera lifecycle, background image processing via isolates,
/// and synchronizes state between the gaze tracking sequence and real-time 
/// smartphone position monitoring.
class NeuralNetSessionController {
  /// Session configuration and participant metadata.
  final NeuralNetSession session;

  /// The camera hardware description to be used for streaming.
  final CameraDescription camera;

  /// Service for handling neural network predictions.
  final ApiService _apiService = ApiService();

  /// The internal Flutter camera controller.
  late CameraController _cameraCtrl;
  
  /// Future representing the camera initialization state.
  late Future<void> _initializeControllerFuture;

  /// Flag indicating that the current frame should be saved as a high-quality photo.
  bool toSavePhoto = false;
  
  /// Counter used for naming saved photographs.
  int photoNumber = 0;

  /// Communication port for sending tasks to the background worker isolate.
  SendPort? _workerSendPort;
  
  /// Flag to prevent concurrent frame processing.
  bool _isProcessing = false;
  
  /// Sequential index of the stream frames processed.
  int _streamIndex = 0;

  /// The maximum valid index for the gaze tracking path.
  int _maxFrameIndex = 0;

  /// Stream of gaze tracking state updates.
  Stream<EyeTrackerState> get eyeTrackerStream => eyeTrackerCtrl.stream;
  
  /// Broadcast controller for gaze tracking state.
  final StreamController<EyeTrackerState> eyeTrackerCtrl = StreamController<EyeTrackerState>.broadcast();
  
  /// Current state of the gaze tracking process.
  EyeTrackerState eyeTrackerState = EyeTrackerState(
    frameNumber: 0,
    pauseTimer: AppConstants.initialPauseSeconds,
    isAppStop: false,
  );
  
  /// Current frame index in the gaze tracking animation path.
  int frameNumber = 0;
  
  /// Countdown timer for resuming the session when position is corrected.
  int pauseTimer = AppConstants.initialPauseSeconds;
  
  /// Whether the session has completed or been manually stopped.
  bool isAppStop = false;

  /// Stream of position marker state updates.
  Stream<PositionMarkerState> get positionMarkerStream => positionMarkerStreamCtrl.stream;
  
  /// Broadcast controller for position marker state.
  final StreamController<PositionMarkerState> positionMarkerStreamCtrl = StreamController<PositionMarkerState>.broadcast();
  
  /// Current state of the smartphone's sensed position.
  PositionMarkerState positionMarkerState = PositionMarkerState(count: 0, height: -1, distance: -1);
  
  /// Total count of position predictions received from the server.
  int positionCount = 0;
  
  /// The current vertical displacement of the smartphone relative to eyes.
  double height = -1;
  
  /// The current distance from the participant's eyes to the smartphone.
  double distance = -1;

  /// Initializes the controller and starts building the camera/worker infrastructure.
  NeuralNetSessionController({
    required this.session,
    required this.camera,
  }) {
    _cameraCtrl = CameraController(
      camera,
      ResolutionPreset.medium,
      imageFormatGroup: ImageFormatGroup.yuv420,
      enableAudio: false,
    );
    _initializeControllerFuture = _cameraCtrl.initialize();
    _cameraCtrl.setFocusMode(FocusMode.locked);
    _initIsolate();
  }

  /// Spawn the background isolate for image processing.
  Future<void> _initIsolate() async {
    final receivePort = ReceivePort();
    await Isolate.spawn(cameraImageWorker, receivePort.sendPort);

    // The first message from the worker is its SendPort.
    final firstMessage = await receivePort.first;
    if (firstMessage is SendPort) {
      _workerSendPort = firstMessage;
      
      // Listen for processing results from the worker.
      receivePort.listen((message) {
        if (message is CameraStreamResult) {
          _handleWorkerResult(message);
        }
      });
    }
  }

  /// Handles results returned from the background worker isolate.
  /// 
  /// Dispatches the luminosity matrix to the prediction server and
  /// saves high-quality images to the gallery if requested.
  Future<void> _handleWorkerResult(CameraStreamResult result) async {
    _isProcessing = false;

    // 1. Send the matrix to the server for prediction.
    if (result.matrix != null) {
      getPosition(result.matrix!, _streamIndex);
    }

    // 2. Save the photo if requested by the gaze tracker.
    if (result.jpegBytes != null && result.photoNumber != null) {
      await ImageGallerySaverPlus.saveImage(
        result.jpegBytes!,
        name: "photo №${result.photoNumber}",
      );
    }
  }

  /// Generates a list of screen coordinates (paddings) for the gaze focus marker.
  ///
  /// The path is defined as a series of target points with smooth transitions between them.
  List<List<double>> getFocusMarkerPaddingList(
    double backgroundPictureSize,
    double focusMarkerSize,
  ) {
    final List<List<double>> result = [];
    final double maxOffset = backgroundPictureSize - focusMarkerSize;

    /// Helper to add a static point with a capture trigger in the middle.
    void addStaticPoint(double x, double y) {
      for (int i = 0; i < 7; i++) {
        result.add([x, y, 0]);
      }
      result.add([x, y, 1]); // Capture point
      for (int i = 0; i < 7; i++) {
        result.add([x, y, 0]);
      }
    }

    /// Helper to add a smooth transition between two points.
    void addTransition(double startX, double startY, double endX, double endY, int steps) {
      for (int i = 1; i <= steps; i++) {
        final double t = i / steps;
        result.add([
          startX + (endX - startX) * t,
          startY + (endY - startY) * t,
          0,
        ]);
      }
    }

    // Define the key waypoints of the experiment path.
    final List<({double x, double y})> waypoints = [
      (x: 0.0, y: 0.0), // 1. Start (Top Left)
      (x: maxOffset, y: maxOffset), // 2. Inner corner of TL quadrant
      (x: maxOffset, y: backgroundPictureSize), // 3. Top right of ML quadrant
      (x: 0.0, y: backgroundPictureSize + maxOffset / 2), // 4. Left edge center
      (x: maxOffset, y: backgroundPictureSize * 2 - focusMarkerSize), // 5. Bottom right of ML
      (x: maxOffset, y: backgroundPictureSize * 2), // 6. Top right of BL quadrant
      (x: 0.0, y: backgroundPictureSize * 3 - focusMarkerSize), // 7. Bottom left corner
      (x: backgroundPictureSize * 2 - focusMarkerSize, y: backgroundPictureSize * 3 - focusMarkerSize), // 8. Bottom right corner
      (x: backgroundPictureSize, y: backgroundPictureSize * 2), // 9. Top left of BR quadrant
      (x: backgroundPictureSize, y: backgroundPictureSize * 2 - focusMarkerSize), // 10. Bottom left of MR
      (x: backgroundPictureSize * 2 - focusMarkerSize, y: backgroundPictureSize + maxOffset / 2), // 11. Right edge center
      (x: backgroundPictureSize, y: backgroundPictureSize), // 12. Top left of MR quadrant
      (x: backgroundPictureSize, y: backgroundPictureSize - focusMarkerSize), // 13. Bottom left of TR
      (x: backgroundPictureSize * 2 - focusMarkerSize, y: 0.0), // 14. Top right corner
    ];

    // Build the collection path frame by frame.
    for (int i = 0; i < waypoints.length; i++) {
      final point = waypoints[i];
      addStaticPoint(point.x, point.y);

      // If there is a next point, add a transition to it.
      if (i < waypoints.length - 1) {
        final nextPoint = waypoints[i + 1];
        addTransition(point.x, point.y, nextPoint.x, nextPoint.y, 30);
      }
    }

    return result;
  }

  /// Starts the gaze tracking animation loop.
  /// 
  /// Iterates through the [list] of coordinates, updating the state every 100ms.
  /// If the current coordinate is a photo trigger, notifies the processor to save the frame.
  Future<void> startEyeTracker(List<List<double>> list) async {
    if (list.isEmpty) return;
    
    _maxFrameIndex = list.length - 1;
    Duration trackerDuration = const Duration(milliseconds: 100);

    while (frameNumber <= _maxFrameIndex) {
      if (isAppStop) break;

      // Update state for current frame before the delay to keep UI reactive.
      _broadcastEyeTrackerState();

      // Trigger photo capture if the list indicates a keypoint.
      if (list[frameNumber][2] == 1) {
        toSavePhoto = true;
      }

      await Future.delayed(trackerDuration);
      if (isAppStop) break;
      
      frameNumber++;
    }
    
    // Final delay before closing the session to allow last processing to finish.
    if (!isAppStop) {
      await Future.delayed(const Duration(milliseconds: 2000));
      if (!isAppStop) stopApp();
    }
  }

  /// Broadcasts the current gaze tracker state.
  /// 
  /// Clamps the [frameNumber] to [_maxFrameIndex] to prevent RangeErrors in the UI.
  void _broadcastEyeTrackerState() {
    if (eyeTrackerCtrl.isClosed) return;
    
    eyeTrackerState = EyeTrackerState(
      frameNumber: frameNumber.clamp(0, _maxFrameIndex),
      pauseTimer: pauseTimer,
      isAppStop: isAppStop,
    );
    eyeTrackerCtrl.add(eyeTrackerState);
  }

  /// Stops the session, disposes of the camera, and notifies listeners.
  void stopApp() {
    if (isAppStop) return;
    isAppStop = true;
    
    // Update state to notify UI about the stop.
    _broadcastEyeTrackerState();
    
    dispose();
  }

  /// Releases all resources, stops streams, and closes controllers.
  void dispose() {
    isAppStop = true;
    _cameraCtrl.dispose();
    _apiService.dispose();
    if (!eyeTrackerCtrl.isClosed) eyeTrackerCtrl.close();
    if (!positionMarkerStreamCtrl.isClosed) positionMarkerStreamCtrl.close();
  }

  /// Starts the smartphone position monitoring via the camera image stream.
  /// 
  /// Ensures the camera is initialized before mounting the image stream handler.
  Future<void> startPositionMarker() async {
    await _initializeControllerFuture;
    
    _cameraCtrl.startImageStream((CameraImage image) {
      if (isAppStop) return;
      _onImageFrame(image);
    });
  }

  /// Entry point for each frame from the camera stream.
  /// 
  /// Offloads the frame to the background isolate for intensive image processing.
  void _onImageFrame(CameraImage image) {
    if (_workerSendPort == null || _isProcessing) return;

    _isProcessing = true;
    _streamIndex++;

    // Prepare processing configuration for the worker.
    final task = CameraStreamTask(
      planes: image.planes.map((p) => p.bytes).toList(),
      width: image.width,
      height: image.height,
      targetWidth: AppConstants.imgWidth,
      targetHeight: AppConstants.imgHeight,
      saveAsQuality: toSavePhoto,
      photoNumber: toSavePhoto ? ++photoNumber : null,
    );

    // Reset the capture flag as the task has been queued.
    if (toSavePhoto) {
      toSavePhoto = false;
    }

    _workerSendPort!.send(task);
  }

  /// Sends the luminosity matrix to the prediction server and updates state.
  /// 
  /// The [matrix] is the processed luminosity data.
  /// The [index] represents the frame order for synchronization.
  Future<void> getPosition(List<List<double>> matrix, int index) async {
    // Ensure we only process requests if the session is active.
    if (isAppStop) return;

    final prediction = await _apiService.getPrediction(matrix: matrix);
    
    if (prediction == null) return;

    // Ensure we only process responses that are newer than our current state.
    if (index > positionCount) {
      positionCount = index;
      height = prediction.sensor;
      distance = prediction.distance;
      
      // Check if the smartphone position is outside valid bounds using centralized constants.
      if (((distance < AppConstants.lowerLimit) || (height < AppConstants.lowerLimit)) || 
          ((distance > AppConstants.upperLimit) || (height > AppConstants.upperLimit))) {
        
        debugPrint('Position out of bounds: H=$height, D=$distance');
        
        pauseTimer = AppConstants.initialPauseSeconds;
        _broadcastEyeTrackerState();
      }
      
      positionMarkerState = PositionMarkerState(
        count: positionCount,
        height: height,
        distance: distance,
      );
      if (!positionMarkerStreamCtrl.isClosed) positionMarkerStreamCtrl.add(positionMarkerState);
    }
  }

  /// Manually saves an [XFile] to the device gallery.
  Future<void> savePhoto(int number, XFile photo) async {
    await ImageGallerySaverPlus.saveImage(
      await photo.readAsBytes(),
      name: "photo №$number",
    );
  }
}

/// Represents the snapshot state of the gaze tracking process.
class EyeTrackerState {
  /// Current index in the gaze path coordinate list.
  final int frameNumber;
  
  /// Countdown until the gaze tracker resumes (if paused).
  final int pauseTimer;
  
  /// Whether the gaze track animation has concluded.
  final bool isAppStop;

  /// Creates a state container for the gaze tracker.
  EyeTrackerState({
    required this.frameNumber,
    required this.pauseTimer,
    required this.isAppStop,
  });
}

/// Represents the snapshot state of the smartphone's spatial position.
class PositionMarkerState {
  /// Sequence number of the prediction.
  final int count;
  
  /// Vertical offset relative to eyes.
  final double height;
  
  /// Distance from eyes.
  final double distance;

  /// Creates a state container for position prediction data.
  PositionMarkerState({
    required this.count,
    required this.height,
    required this.distance,
  });
}
