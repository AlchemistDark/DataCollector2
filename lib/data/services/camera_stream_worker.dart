import 'dart:isolate';
import 'dart:typed_data';
import 'package:image/image.dart' as img;

/// Data package sent to the worker isolate for processing.
/// 
/// Contains raw camera planes and target dimensions for resizing.
class CameraStreamTask {
  /// Raw YUV planes from the camera.
  final List<Uint8List> planes;
  
  /// Original width of the camera frame.
  final int width;
  
  /// Original height of the camera frame.
  final int height;
  
  /// Deserted width for the resized output matrix.
  final int targetWidth;
  
  /// Desired height for the resized output matrix.
  final int targetHeight;
  
  /// Whether to encode and return a high-quality JPEG of the frame.
  final bool saveAsQuality;
  
  /// The index of the photograph if it's being saved to the gallery.
  final int? photoNumber;

  /// Creates a new [CameraStreamTask].
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

/// Result return package from the worker isolate.
/// 
/// Contains the processed luminosity matrix and optional high-quality JPEG bytes.
class CameraStreamResult {
  /// A 2D matrix of luminosity values for neural network input.
  final List<List<double>>? matrix;
  
  /// Encoded JPEG bytes of the camera frame.
  final Uint8List? jpegBytes;
  
  /// The sequence number of the photo, if this result relates to a saved image.
  final int? photoNumber;

  /// Creates a [CameraStreamResult] containing processed data.
  CameraStreamResult({
    this.matrix,
    this.jpegBytes,
    this.photoNumber,
  });
}

/// The main entry point for the background worker isolate.
/// 
/// This isolate handles heavy image processing tasks (YUV conversion, resizing, 
/// matrix generation, and JPEG encoding) to keep the UI thread responsive.
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
      // Silent error handling to prevent isolate crash
      // print("Worker Error: $e");
    }
  }
}

/// Converts YUV420_888 format camera planes to a standard [img.Image].
/// 
/// Performs manual YUV to RGB color space conversion.
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

      // Standard YUV to RGB conversion formula
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

/// Generates a luminosity matrix from RGB bytes.
/// 
/// Averages RGB channels to get a single luminosity value per pixel
/// and formats it into a 2D list according to the specified [width].
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
