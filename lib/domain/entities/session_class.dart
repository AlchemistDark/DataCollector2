/// Represents the metadata for a neural network data collection session.
///
/// This class holds information about the user, their device, and session configuration
/// which is used to label collected data.
class NeuralNetSession {
  /// The unique identifier or number of the session participant.
  final String number;
  
  /// The gender of the participant.
  final Gender gender;
  
  /// The mobile device model being used for collection.
  final PhoneModel phoneModel;
  
  /// The duration (in seconds) the focus marker stays on screen.
  final double screenTime;
  
  /// The duration (in seconds) during which photos are captured at a marker position.
  final double photoTime;
  
  /// Whether to show a background pattern behind the focus marker.
  final bool? showBackground;
  
  /// Whether to enable camera hardware auto-focus during the session.
  final bool? autoFocusEnable;

  /// Creates a new [NeuralNetSession] with the specified parameters.
  NeuralNetSession(
    this.number,
    this.gender,
    this.phoneModel,
    this.screenTime,
    this.photoTime,
    this.showBackground,
    this.autoFocusEnable,
  );
}

/// Defines the operational mode of the application.
enum AppMode { 
  /// Standard neural network data collection mode.
  neuralNetCenter 
}

/// The gender categories for session metadata.
enum Gender { male, female }

/// Supported smartphone models for data normalization.
enum PhoneModel { redmy, sony, samsung }