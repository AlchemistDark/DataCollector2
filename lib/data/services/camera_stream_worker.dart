import 'dart:isolate';
import 'dart:typed_data';
import 'package:image/image.dart' as img;

/// Task sent to the worker isolate
class CameraStreamTask {
  final List<Uint8List> planes;
  final int width;
  final int height;
  final int targetWidth;
  final int targetHeight;
  final bool saveAsQuality;
  final int? photoNumber;

  CameraStreamTask({
    required this.planes,
    required this.width,
    required this.height,
    required this.targetWidth,
    required this.targetHeight,
    this.saveAsQuality = false,
    this.photoNumber,
  });
}

/// Result returned from the worker isolate
class CameraStreamResult {
  final List<List<double>>? matrix;
  final Uint8List? jpegBytes;
  final int? photoNumber;

  CameraStreamResult({
    this.matrix,
    this.jpegBytes,
    this.photoNumber,
  });
}

/// The main entry point for the worker isolate
void cameraImageWorker(SendPort sendPort) async {
  final port = ReceivePort();
  sendPort.send(port.sendPort);

  await for (final CameraStreamTask task in port) {
    try {
      // 1. Convert YUV to RGB Image
      final image = _convertYUV420ToImage(task);

      List<List<double>>? matrix;
      Uint8List? jpegBytes;

      // 2. Prepare prediction matrix (resized)
      final resizedForAI = img.copyResize(
        image,
        width: task.targetWidth,
        height: task.targetHeight,
      );

      final rgbBytes = resizedForAI.toUint8List();
      matrix = _generateMatrix(rgbBytes, task.targetWidth);

      // 3. Prepare quality JPEG if requested
      if (task.saveAsQuality) {
         jpegBytes = img.encodeJpg(image, quality: 90);
      }

      sendPort.send(CameraStreamResult(
        matrix: matrix,
        jpegBytes: jpegBytes,
        photoNumber: task.photoNumber,
      ));
    } catch (e) {
      // In case of error, we don't want to crash the isolate
      print("Worker Error: $e");
    }
  }
}

/// Converts YUV420_888 to img.Image
img.Image _convertYUV420ToImage(CameraStreamTask task) {
  final int width = task.width;
  final int height = task.height;
  final planes = task.planes;

  final yPlane = planes[0];
  final uPlane = planes[1];
  final vPlane = planes[2];

  final image = img.Image(width: width, height: height);
  
  final int uvWidth = width ~/ 2;
  
  for (int y = 0; y < height; y++) {
    for (int x = 0; x < width; x++) {
      final int yIndex = y * width + x;
      final int uvIndex = (y ~/ 2) * uvWidth + (x ~/ 2);

      final int yp = yPlane[yIndex];
      final int up = uPlane[uvIndex];
      final int vp = vPlane[uvIndex];

      // Standard YUV to RGB conversion
      int r = (yp + 1.402 * (vp - 128)).toInt();
      int g = (yp - 0.344136 * (up - 128) - 0.714136 * (vp - 128)).toInt();
      int b = (yp + 1.772 * (up - 128)).toInt();

      image.setPixelRgb(x, y, 
        r.clamp(0, 255),
        g.clamp(0, 255),
        b.clamp(0, 255),
      );
    }
  }
  return image;
}

/// Ported logic from original compressingArrayByThree and slicer
List<List<double>> _generateMatrix(Uint8List rgbBytes, int width) {
  final List<double> averages = [];
  
  for (int i = 0; i < rgbBytes.length; i += 3) {
    final double avg = (rgbBytes[i] + rgbBytes[i + 1] + rgbBytes[i + 2]) / 3.0;
    averages.add(avg);
  }

  final List<List<double>> result = [];
  for (int i = 0; i < averages.length; i += width) {
    final end = (i + width < averages.length) ? i + width : averages.length;
    result.add(averages.sublist(i, end));
  }
  return result;
}
