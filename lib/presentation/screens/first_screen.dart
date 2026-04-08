import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import 'package:data_collector2/presentation/screens/neural_net_session_screen.dart';
import 'package:data_collector2/presentation/controllers/neural_net_session_controller.dart';
import 'package:data_collector2/domain/entities/session_class.dart';

/// The initial configuration screen where the user sets session parameters.
/// 
/// Allows inputting participant ID, gender, smartphone model, and 
/// toggling background visibility before starting the experiment.
class FirstPage extends StatefulWidget {
  /// The camera description obtained during app initialization.
  final CameraDescription camera;

  /// Creates a [FirstPage] with the provided camera.
  const FirstPage({super.key, required this.camera});

  @override
  State<FirstPage> createState() => _FirstPageState();
}

class _FirstPageState extends State<FirstPage> {
  /// The selected application mode (defaults to neural network data collection).
  AppMode appMode = AppMode.neuralNetCenter;

  /// Participant identifier used for data labeling.
  String number = "0";
  
  /// Gender of the participant.
  Gender gender = Gender.male;
  
  /// Smartphone model used for the current collection session.
  PhoneModel model = PhoneModel.sony;

  /// Session timing settings (some values are currently using defaults).
  double screenTime = 3.0;
  double photoTime = 1.0;
  double delay = 5.0;
  
  /// Whether to display a background pattern behind the focus marker.
  bool? showBackground = false;
  
  /// Whether to enable auto-focus during the session.
  bool? autoFocusEnable = false;

  /// Generates the sequence of target positions for the gaze tracker.
  /// 
  /// Uses a predefined list of coordinate points and shuffles them 
  /// to randomize the collection path.
  List<List<int>> _generateListForNeuralNetScreen() {
    List<List<int>> temp = [[1, 1], [1, 2], [2, 1], [2, 2], [3, 1], [3, 2]];
    List<List<int>> result = [[1, 1], [1, 2], [2, 1], [2, 2], [3, 1], [3, 2]];
    temp.shuffle();
    result.addAll(temp);
    return result;
  }

  /// Updates the participant number when input changes.
  void _onNumberChanged(String newText) {
    setState(() {
      number = newText;
    });
  }

  /// Entry point for starting the session based on the current [appMode].
  void _startUp() {
    if (number.trim().isEmpty || number == "0") {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Пожалуйста, введите корректный номер участника"),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    switch (appMode) {
      case AppMode.neuralNetCenter:
        _neuralNetModeStart();
        break;
    }
  }

  /// Initializes the controller and navigates to the experiment screen.
  void _neuralNetModeStart() {
    NeuralNetSession session = NeuralNetSession(
      number,
      gender,
      model,
      screenTime,
      photoTime,
      showBackground,
      autoFocusEnable,
    );
    List<List<int>> list = _generateListForNeuralNetScreen();
    NeuralNetSessionController controller = NeuralNetSessionController(
      session: session,
      camera: widget.camera,
    );
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) {
          return NeuralNetSessionScreen(
            controller: controller,
            session: session,
            list: list,
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Session Setup"),
      ),
      body: ListView(
        shrinkWrap: true,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Номер участника",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                TextField(
                  keyboardType: TextInputType.number,
                  onChanged: _onNumberChanged,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: "Например: 123",
                    prefixIcon: Icon(Icons.person),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  "Пол",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                RadioListTile<Gender>(
                  title: const Text('Мужской'),
                  value: Gender.male,
                  groupValue: gender,
                  onChanged: (Gender? value) {
                    setState(() {
                      gender = value!;
                    });
                  },
                ),
                RadioListTile<Gender>(
                  title: const Text('Женский'),
                  value: Gender.female,
                  groupValue: gender,
                  onChanged: (Gender? value) {
                    setState(() {
                      gender = value!;
                    });
                  },
                ),
                const SizedBox(height: 24),
                const Text(
                  "Модель смартфона",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                RadioListTile<PhoneModel>(
                  title: const Text('Redmy'),
                  value: PhoneModel.redmy,
                  groupValue: model,
                  onChanged: (PhoneModel? value) {
                    setState(() {
                      model = value!;
                    });
                  },
                ),
                RadioListTile<PhoneModel>(
                  title: const Text('Sony'),
                  value: PhoneModel.sony,
                  groupValue: model,
                  onChanged: (PhoneModel? value) {
                    setState(() {
                      model = value!;
                    });
                  },
                ),
                RadioListTile<PhoneModel>(
                  title: const Text('Samsung'),
                  value: PhoneModel.samsung,
                  groupValue: model,
                  onChanged: (PhoneModel? value) {
                    setState(() {
                      model = value!;
                    });
                  },
                ),
                const SizedBox(height: 24),
                CheckboxListTile(
                  title: const Text("Показывать фон?"),
                  subtitle: const Text("Отображать узор за маркером"),
                  value: showBackground,
                  onChanged: (newValue) {
                    setState(() {
                      showBackground = newValue;
                    });
                  },
                  controlAffinity: ListTileControlAffinity.leading,
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _startUp,
        tooltip: 'Start',
        icon: const Icon(Icons.play_arrow),
        label: const Text("Начать"),
      ),
    );
  }
}