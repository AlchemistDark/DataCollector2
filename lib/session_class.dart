class NeuralNetSession{
  final String number;
  final Gender gender;
  final PhoneModel phoneModel;
  final double screenTime;
  final double photoTime;
  final bool? showBackground;
  final bool? autoFocusEnable;

  NeuralNetSession(
    this.number,
    this.gender,
    this.phoneModel,
    this.screenTime,
    this.photoTime,
    this.showBackground,
    this.autoFocusEnable
  );
}

enum AppMode {neuralNetCenter}

enum Gender {male, female}

enum PhoneModel {redmy, sony, samsung}