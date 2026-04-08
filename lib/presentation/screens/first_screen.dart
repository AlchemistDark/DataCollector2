import 'package:camera/camera.dart';

import 'package:flutter/material.dart';

import 'package:data_collector2/presentation/screens/neural_net_session_screen.dart';
import 'package:data_collector2/presentation/controllers/neural_net_session_controller.dart';
import 'package:data_collector2/domain/entities/session_class.dart';

/// Экран предварительной настройки.

class FirstPage extends StatefulWidget {
  final CameraDescription camera;
  const FirstPage({super.key, required this.camera});

  @override
  State<FirstPage> createState() => _FirstPageState();
}

class _FirstPageState extends State<FirstPage> {

  /// Режим приложения (пока не используется).
  AppMode appMode = AppMode.neuralNetCenter;

  ///Поля которые пойду в название фотографий.
  String number = "0";
  Gender gender = Gender.male;
  PhoneModel model = PhoneModel.sony;

  /// Настройки сессий (часть пока не используется).
  double screenTime = 3.0;
  double photoTime = 1.0;
  double delay = 5.0;
  bool? showBackground = false;
  bool? autoFocusEnable = false;

  /// Порядок отображения полоений маркера направления взгляда (пока не используется).
  List<List<int>> _generateListForNeuralNetScreen(){
    List<List<int>> temp = [[1, 1], [1, 2], [2, 1], [2, 2], [3, 1], [3, 2]];
    List<List<int>> result = [[1, 1], [1, 2], [2, 1], [2, 2], [3, 1], [3, 2]];
    temp.shuffle();
    result.addAll(temp);
    return result;
  }

  void _onNumberChanged(String newText){
    number = newText;
  }

  void _startUp(){
    switch(appMode) {
      case AppMode.neuralNetCenter:
        _neuralNetModeStart();
        break;
    }
  }

  void _neuralNetModeStart(){
    NeuralNetSession session = NeuralNetSession(
      number,
      gender,
      model,
      screenTime,
      photoTime,
      showBackground,
      autoFocusEnable
    );
    List<List<int>> list = _generateListForNeuralNetScreen();
    NeuralNetSessionController controller = NeuralNetSessionController(
      session: session,
      camera: widget.camera,
    );
    Navigator.push(
      context, MaterialPageRoute(
        builder: (context) {
          return NeuralNetSessionScreen(
            controller: controller,
            session: session,
            //camera: widget.camera,
            list: list
          );
        }
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Введите настройки"),
      ),
      body: ListView(
        shrinkWrap: true,
        children: [
          Column(
            children: [
              const Text("Номер"),
              TextField(
                keyboardType: TextInputType.number,
                onChanged: (newText)=>_onNumberChanged(newText),
                onSubmitted: (newText)=>_onNumberChanged(newText),
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: "Вводить сюда",
                ),
              ),
              const Text("Пол"),
              ListTile(
                title: const Text('Мужской'),
                leading: Radio<Gender>(
                  value: Gender.male,
                  groupValue: gender,
                  onChanged: (Gender? value) {
                    setState(() {
                      gender = value!;
                    });
                  },
                ),
              ),
              ListTile(
                title: const Text('Женский'),
                leading: Radio<Gender>(
                  value: Gender.female,
                  groupValue: gender,
                  onChanged: (Gender? value) {
                    setState(() {
                      gender = value!;
                    });
                  },
                ),
              ),
              const Text("Модель смартфона"),
              ListTile(
                title: const Text('Redmy'),
                leading: Radio<PhoneModel>(
                  value: PhoneModel.redmy,
                  groupValue: model,
                  onChanged: (PhoneModel? value) {
                    setState(() {
                      model = value!;
                    });
                  },
                ),
              ),
              ListTile(
                title: const Text('Sony'),
                leading: Radio<PhoneModel>(
                  value: PhoneModel.sony,
                  groupValue: model,
                  onChanged: (PhoneModel? value) {
                    setState(() {
                      model = value!;
                    });
                  },
                ),
              ),
              ListTile(
                title: const Text('Samsung'),
                leading: Radio<PhoneModel>(
                  value: PhoneModel.samsung,
                  groupValue: model,
                  onChanged: (PhoneModel? value) {
                    setState(() {
                      model = value!;
                    });
                  },
                ),
              ),
              CheckboxListTile(
                title: const Text("Показывать фон?"),
                value: showBackground,
                onChanged: (newValue) {
                  setState(() {
                    showBackground = newValue;
                  });
                },
                controlAffinity: ListTileControlAffinity.leading,  //  <-- leading Checkbox
              ),
            ]
          )
        ]
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _startUp,
        tooltip: 'Start',
        child: const Text("Начать"),
      ),
    );
  }
}