import 'package:camera/camera.dart';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

//import 'package:data_collector2/buttons.dart';
import 'package:data_collector2/neural_net_session_screen.dart';
import 'package:data_collector2/neural_net_session_controller.dart';
import 'package:data_collector2/session_class.dart';

/// Экран предварительной настройки.

class FirstPage extends StatefulWidget {
  final CameraDescription camera;
  const FirstPage({Key? key, required this.camera}) : super(key: key);

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

  // void _delayUp(){
  //   delay = delay + 0.5;
  //   setState(() {});
  //   //}
  // }
  //
  // void _delayDown(){
  //   if(delay > 0) {
  //     delay = delay - 0.5;
  //     setState(() {});
  //   }
  // }
  //
  // void _screenTimeUp(){
  //   //if(screenTime < 3.0) {
  //     screenTime = screenTime + 0.5;
  //     setState(() {});
  //   //}
  // }
  //
  // void _screenTimeDown(){
  //   if(screenTime > 0.5) {
  //     screenTime = screenTime - 0.5;
  //     setState(() {});
  //   }
  // }
  //
  // void _photoTimeUp(){
  //   if(photoTime < screenTime) {
  //     photoTime = photoTime + 0.05;
  //     setState(() {});
  //   }
  // }
  //
  // void _photoTimeDown(){
  //   if(photoTime > 0.1) {
  //     photoTime = photoTime - 0.05;
  //     setState(() {});
  //   }
  // }

  void _startUp(){
    switch(appMode) {
      case AppMode.neuralNetCenter:
        _neuralNetModeStart();
        break;
    }
  }

  void _neuralNetModeStart(){
    NeuralNetSessionController controller = NeuralNetSessionController(
      camera: widget.camera,
    );
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
              // const Text("Режим"),
              // ListTile(
              //   title: const Text('Пока единественный режим'),
              //   leading: Radio<AppMode>(
              //     value: AppMode.neuralNetCenter,
              //     groupValue: appMode,
              //     onChanged: (AppMode? value) {
              //       setState(() {
              //         appMode = value!;
              //       });
              //     },
              //   ),
              // ),
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
              //if(appMode == AppMode.calibration || appMode == AppMode.collection || appMode == AppMode.unCenter)
              // const Text("Расстояние"),
              //if(appMode == AppMode.calibration || appMode == AppMode.collection || appMode == AppMode.unCenter)
              // ListTile(
              //   title: const Text('15 см'),
              //   leading: Radio<Distance>(
              //     value: Distance.x15,
              //     groupValue: distance,
              //     onChanged: (Distance? value) {
              //       setState(() {
              //         distance = value!;
              //       });
              //     },
              //   ),
              // ),
              // if(appMode == AppMode.calibration || appMode == AppMode.collection || appMode == AppMode.unCenter)
              // ListTile(
              //   title: const Text('30 см'),
              //   leading: Radio<Distance>(
              //     value: Distance.x30,
              //     groupValue: distance,
              //     onChanged: (Distance? value) {
              //       setState(() {
              //         distance = value!;
              //       });
              //     },
              //   ),
              // ),
              // if(appMode == AppMode.calibration || appMode == AppMode.collection || appMode == AppMode.unCenter)
              // const Text("Время между крестиками"),
              // if(appMode == AppMode.calibration || appMode == AppMode.collection || appMode == AppMode.unCenter)
              // Row(
              //   children: [
              //      Expanded(
              //       child: Text(
              //         '$screenTime',
              //         textAlign: TextAlign.center
              //       )
              //     ),
              //     AnimatedButton(
              //       icon: const Icon(Icons.add),
              //       onPressed: (){
              //         setState((){_screenTimeUp();});
              //       }
              //     ),
              //     AnimatedButton(
              //       icon: const Icon(Icons.remove),
              //       onPressed: (){setState((){_screenTimeDown();});}
              //     )
              //   ]
              // ),
              // if(appMode == AppMode.calibration || appMode == AppMode.collection || appMode == AppMode.unCenter)
              // const Text("Время между фото"),
              // if(appMode == AppMode.calibration || appMode == AppMode.collection || appMode == AppMode.unCenter)
              // Row(
              //   children: [
              //     Expanded(
              //       child: Text(
              //         photoTime.toStringAsPrecision(2),
              //         textAlign: TextAlign.center
              //       )
              //     ),
              //     AnimatedButton(
              //       icon: const Icon(Icons.add),
              //       onPressed: (){setState((){_photoTimeUp();});}
              //     ),
              //     AnimatedButton(
              //       icon: const Icon(Icons.remove),
              //       onPressed: (){setState((){_photoTimeDown();});}
              //     )
              //   ]
              // ),
              //if(appMode != AppMode.demo)
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
              // if(appMode != AppMode.demo)
              // CheckboxListTile(
              //   title: const Text("Использовать автофокус?"),
              //   value: autoFocusEnable,
              //   onChanged: (newValue) {
              //     setState(() {
              //       autoFocusEnable = newValue;
              //     });
              //   },
              //   controlAffinity: ListTileControlAffinity.leading,  //  <-- leading Checkbox
              // )
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