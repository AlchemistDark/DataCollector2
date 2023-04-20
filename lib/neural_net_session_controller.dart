import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:dio/dio.dart';
import 'package:image/image.dart' as img;
import 'package:image_gallery_saver/image_gallery_saver.dart';

import 'package:data_collector2/session_class.dart';

/// Контроллер сессии для теста взаимодействия с нейросетью.

class NeuralNetSessionController{

  final CameraDescription camera;

  /// Размер фото, которое принимает нейросеть, определяющая позицию смартфона.
  final int imgWidth = 120;
  final int imgHeight = 180;

  /// Наклон смартфона.
  double tilt = -1;

  /// Дистанция до смартфона.
  double distance = -1;

  /// ToDo
  int timerCount = 30;
  int frameNumber = 0;
  bool isStop = false;
  String log = '';

  ScreenState screenState = ScreenState(-1, -1, 30, 0, false, '');

  late CameraController _controller;
  late Future<void> _initializeControllerFuture;
  late final List<List<double>> focusMarkerPaddingList;

  ///Todo
  Stream<ScreenState> get positionState => positionStateCtrl.stream;
  final StreamController<ScreenState> positionStateCtrl = StreamController<ScreenState>.broadcast();

  NeuralNetSessionController({
    required this.camera
  }){
    _controller = CameraController(
      camera,
      ResolutionPreset.max,
      imageFormatGroup: ImageFormatGroup.yuv420
    );
    _initializeControllerFuture = _controller.initialize();
    _controller.setFocusMode(FocusMode.locked);
    takePhotoCycle();
  }

  Future<void> takePhotoCycle() async{
    for (int i = 0; i < 30; i++){
      if (i == 15) {
        await makePhotoForGetPositionAndSave(i);
      }else{
        await makePhotoForGetPositionOnly(i);
      }
    }
    screenState = ScreenState(tilt, distance, timerCount, frameNumber, isStop, log);
    positionStateCtrl.add(screenState);
  }

  Future<void> makePhotoForGetPositionOnly(int index) async {
    _controller.setFocusMode(FocusMode.locked);
    try {
      print('$index Страт фото для позиции ${DateTime.now().second} ${DateTime.now().millisecond}');
      log = "$log /n $index Страт фото для позиции ${DateTime.now().second} ${DateTime.now().millisecond}";
      await _initializeControllerFuture;
      final XFile photo = await _controller.takePicture();
      final File file = File(photo.path);
      final img.Image resizedPhoto = img.copyResize(img.decodeImage(await file.readAsBytes())!, width: imgWidth, height: imgHeight);
      final List<int> biteList = resizedPhoto.getBytes(format: img.Format.rgb).toList();
      final List<double> pointsList = compressingArrayByThree(biteList);
      final List<List<double>> pointsMatrix = sliceArray(pointsList, imgWidth);
      print (pointsMatrix);
      getPosition(pointsMatrix, index);
      print('$index Конец фото для позиции ${DateTime.now().second} ${DateTime.now().millisecond}');
      log = "$log /n $index Конец фото для позиции ${DateTime.now().second} ${DateTime.now().millisecond}";
    } catch(e){
      print("$index Ошибка фото для позиции $e");
      log = "$log /n $index Ошибка фото для позиции $e";
    }
  }

  Future<void> makePhotoForGetPositionAndSave(int index) async{
    _controller.setFocusMode(FocusMode.auto);
    try {
      print('$index Страт фото для сохранения ${DateTime.now().second} ${DateTime.now().millisecond}');
      log = "$log /n $index Страт фото для сохранения ${DateTime.now().second} ${DateTime.now().millisecond}";
      await _initializeControllerFuture;
      final XFile photo = await _controller.takePicture();
      final File file = File(photo.path);
      final img.Image resizedPhoto = img.copyResize(img.decodeImage(await file.readAsBytes())!, width: imgWidth, height: imgHeight);
      final List<int> biteList = resizedPhoto.getBytes(format: img.Format.rgb).toList();
      final List<double> pointsList = compressingArrayByThree(biteList);
      final List<List<double>> pointsMatrix = sliceArray(pointsList, imgWidth);
      print (pointsMatrix);
      getPosition(pointsMatrix, index);
      print('$index Начало сохранения ${DateTime.now().second} ${DateTime.now().millisecond}');
      log = "$log /n $index Начало сохранения ${DateTime.now().second} ${DateTime.now().millisecond}";
      await ImageGallerySaver.saveImage(
        await photo.readAsBytes(),
        name: "photo"
      );
      print('$index Конец фото для сохранения ${DateTime.now().millisecond}');
      log = "$log /n $index Конец фото для сохранения ${DateTime.now().millisecond}";
    } catch(e){
      print(e);
      log = "$log /n $e";
    }
  }

  /// Групирует числа входящего массива по три подряд и возвращает массив средних арефметических этих чисел.
  List<double> compressingArrayByThree(List<num> input){
    List<double> result = [];
    double sum = 0;
    double average = 0;
    for (int i = 0; i < input.length; i++){
      switch (i % 3){
        case 0:
          sum = 0;
          average = 0;
          sum += input[i];
          break;
        case 1:
          sum += input[i];
          break;
        case 2:
          sum += input[i];
          average = sum / 3;
          result.add(average);
          break;
      }
    }
    return result;
  }

  /// Нарезает непрерывный массив на массив массивов.
  List<List<double>> sliceArray (List<double> list, int size){
    int len = list.length;
    List<List<double>> result = [];
    for (int i = 0; i < len; i+= size){
      final end = (i + size < len)? i + size:len;
      result.add(list.sublist(i, end));
    }
    return result;
  }

  /// Посылает данные на сервер и ToDo.
  Future<void> getPosition(Object forwardedData, int index) async{
    print('$index Начало получения позиции ${DateTime.now().second} ${DateTime.now().millisecond}');
    log = "$log /n $index Начало получения позиции ${DateTime.now().second} ${DateTime.now().millisecond}";
    try {
      Response response = await Dio().post(
        'https://qviz.fun/api/v1/get/predict/',
        data: {"photo": forwardedData});
      print('$index Конец получения позиции ${DateTime.now().second} ${DateTime.now().millisecond}');
      log = "$log /n $index Конец получения позиции ${DateTime.now().second} ${DateTime.now().millisecond}";
      print("$index Позиция ${response.data}");
      log = "$log /n $index Позиция ${response.data}";

      final Map<String, dynamic> json = response.data;
      tilt = json["sensor"] as double;
      distance = json["distance"] as double;
      screenState =
          ScreenState(tilt, distance, timerCount, frameNumber, isStop, log);
      positionStateCtrl.add(screenState);
    } catch(e){
      print(e);
      log = "$log /n $e";
    }
  }

}

class ScreenState{

  final double tilt;
  final double distance;

  /// ToDo
  final int timerCount;
  final int frameNumber;
  final bool isStop;
  final String log;

  ScreenState(this.tilt, this.distance, this.timerCount, this.frameNumber, this.isStop, this.log);

}