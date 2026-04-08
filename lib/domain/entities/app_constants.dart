/// Centralized configuration constants for the DataCollector2 application.
class AppConstants {
  // --- Network Configuration ---
  
  /// The base domain for the prediction server.
  static const String apiAuthority = 'qviz.fun';
  
  /// The endpoint path for smartphone position prediction.
  static const String predictPath = '/api/v1/get/predict/';

  // --- Image Processing Constants ---
  
  /// Target image width for neural network input.
  static const int imgWidth = 120;
  
  /// Target image height for neural network input.
  static const int imgHeight = 180;

  // --- Smartphone Position Limits ---
  
  /// Minimum acceptable vertical/distance value for a valid smartphone position.
  static const double lowerLimit = -0.375;
  
  /// Maximum acceptable vertical/distance value for a valid smartphone position.
  static const double upperLimit = 0.345;

  // --- Session defaults ---
  
  /// Initial countdown time for pause timer.
  static const int initialPauseSeconds = 3;
}
