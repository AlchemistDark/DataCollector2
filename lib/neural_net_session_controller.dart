import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:dio/dio.dart';
import 'package:image/image.dart' as img;
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:google_ml_kit/google_ml_kit.dart';
import 'package:http/http.dart' as http;

import 'package:data_collector2/session_class.dart';

/// Контроллер сессии для теста взаимодействия с нейросетью.

class NeuralNetSessionController{

  /// Данные для сессии со стартового экрана.
  final NeuralNetSession session;

  final CameraDescription camera;

  final String serverAddress = 'https://qviz.fun/api/v1/get/predict/';

  /// Клиент для REST API создаётся здесь. Один на весь сеанс пользователя.
  final http.Client client = http.Client();

  /// Контроллер камеры.
  late CameraController _cameraCtrl;
  late Future<void> _initializeControllerFuture;

  /// Размер фото, которое принимает нейросеть, определяющая позицию смартфона.
  final int imgWidth = 120;
  final int imgHeight = 180;

  /// Нижняя допустимая граница положения смартфона.
  final double lowerLimit = -0.375;
  /// Верхняя дорустимая граница положения смартфона.
  final double upperLimit = 0.345;

  /// Флаг, что фото надо сохранить.
  bool toSavePhoto = false;
  /// Номер сохраняемой фотографии.
  int photoNumber = 0;

  /// Стрим состояния глазного трекера.
  Stream<EyeTrackerState> get eyeTrackerStream => eyeTrackerCtrl.stream;
  final StreamController<EyeTrackerState> eyeTrackerCtrl
      = StreamController<EyeTrackerState>.broadcast();
  EyeTrackerState eyeTrackerState = EyeTrackerState(
    frameNumber: 0,
    pauseTimer: 3,
    isAppStop: false
  );
  /// Номер кадра анимации.
  int frameNumber = 0;
  /// Таймер отсчёта паузы,
  /// если положение смартфона не соответсвует допустимому.
  int pauseTimer = 3;
  /// Флаг, что анимация закончилась и приложение надо остановить.
  bool isAppStop = false;

  /// Стрим состояния индикатора положения смартфона.
  Stream<PositionMarkerState> get positionMarkerStream
      => positionMarkerStreamCtrl.stream;
  final StreamController<PositionMarkerState> positionMarkerStreamCtrl
      = StreamController<PositionMarkerState>.broadcast();
  int positionMarkerScreenStatus = 0;
  PositionMarkerState positionMarkerState
      = PositionMarkerState(count: 0,  height: -1, distance: -1);
  /// Количество ответов от сервера, возвращающего значеия позиции смартфона.
  int positionCount = 0;
  /// Высота смартфона относительно глаз.
  double height = -1;
  /// Дистанция до смартфона.
  double distance = -1;


  /// Конструктор.
  NeuralNetSessionController({
    required this.session,
    required this.camera
  }){
    _cameraCtrl = CameraController(
      camera,
      ResolutionPreset.medium,
      imageFormatGroup: ImageFormatGroup.yuv420
    );
    _initializeControllerFuture = _cameraCtrl.initialize();
    _cameraCtrl.setFocusMode(FocusMode.locked);
  }

  /// Создаёт список оступов для маркера глазного треккера.
  List<List<double>> getFocusMarkerPaddingList(
    backgroundPictureSize,
    focusMarkerSize
  ){
    List<List<double>> result = [];

    /// Первое число - горизонтальный отступ, второе - вертикальный отступ,
    /// третье - если 1, то с этой позиции надо делать фото, если 0 - не надо.

    // 1. Начало.
    for (int i = 1; i < 8; i++){
      result.add([0, 0, 0]);
    }
    result.add([0, 0, 1]);
    for (int i = 1; i < 8; i++){
      result.add([0, 0, 0]);
    }
    // Путь от 1 к 2.
    for (int i = 1; i < 31; i++){
      result.add([
        (backgroundPictureSize - focusMarkerSize) / 30 * i,
        (backgroundPictureSize - focusMarkerSize) / 30 * i,
        0
      ]);
    }
    // 2. Правый нижний угол верхнего левого квадрата
    for (int i = 1; i < 8; i++){
      result.add([
        (backgroundPictureSize - focusMarkerSize),
        (backgroundPictureSize - focusMarkerSize),
        0
      ]);
    }
    result.add([
      (backgroundPictureSize - focusMarkerSize),
      (backgroundPictureSize - focusMarkerSize),
      1
    ]);
    for (int i = 1; i < 8; i++){
      result.add([
        (backgroundPictureSize - focusMarkerSize),
        (backgroundPictureSize - focusMarkerSize),
        0
      ]);
    }
    // Путь от 2 к 3.
    for (int i = 1; i < 31; i++){
      result.add([
        (backgroundPictureSize - focusMarkerSize),
        ((backgroundPictureSize - focusMarkerSize) + (focusMarkerSize / 30 * i)),
        0
      ]);
    }
    // 3. Правый верхний угол среднего левого квадрата
    for (int i = 1; i < 8; i++){
      result.add([
        (backgroundPictureSize - focusMarkerSize),
        (backgroundPictureSize),
        0
      ]);
    }
    result.add([
      (backgroundPictureSize - focusMarkerSize),
      (backgroundPictureSize),
      1
    ]);
    for (int i = 1; i < 8; i++){
      result.add([
        (backgroundPictureSize - focusMarkerSize),
        (backgroundPictureSize),
        0
      ]);
    }
    // Путь от 3 к 4.
    for (int i = 1; i < 31; i++){
      result.add([
        ((backgroundPictureSize - focusMarkerSize)
            - ((backgroundPictureSize - focusMarkerSize) / 30 * i)),
        (backgroundPictureSize
            + (backgroundPictureSize - focusMarkerSize) / 60 * i),
        0
      ]);
    }
    // 4. Середина левой грани среднего левого квадрата
    for (int i = 1; i < 8; i++){
      result.add([
        0,
        (backgroundPictureSize + (backgroundPictureSize - focusMarkerSize) / 2),
        0
      ]);
    }
    result.add([
      0,
      (backgroundPictureSize + (backgroundPictureSize - focusMarkerSize) / 2),
      1
    ]);
    for (int i = 1; i < 8; i++){
      result.add([
        0,
        (backgroundPictureSize + (backgroundPictureSize - focusMarkerSize) / 2),
        0
      ]);
    }
    // Путь от 4 к 5.
    for (int i = 1; i < 31; i++){
      result.add([
        (backgroundPictureSize - focusMarkerSize) / 30 * i,
        ((backgroundPictureSize + (backgroundPictureSize - focusMarkerSize) / 2)
            + ((backgroundPictureSize - focusMarkerSize) / 60 * i)),
        0
      ]);
    }
    // 5. Правый нижний угол среднего левого квадрата
    for (int i = 1; i < 8; i++){
      result.add([
        (backgroundPictureSize - focusMarkerSize),
        (backgroundPictureSize * 2 - focusMarkerSize),
        0
      ]);
    }
    result.add([
      (backgroundPictureSize - focusMarkerSize),
      (backgroundPictureSize * 2 - focusMarkerSize),
      1
    ]);
    for (int i = 1; i < 8; i++){
      result.add([
        (backgroundPictureSize - focusMarkerSize),
        (backgroundPictureSize * 2 - focusMarkerSize),
        0
      ]);
    }
    // Путь от 5 к 6.
    for (int i = 1; i < 31; i++){
      result.add([
        (backgroundPictureSize - focusMarkerSize),
        ((backgroundPictureSize * 2 - focusMarkerSize)
            + (focusMarkerSize / 30 * i)),
        0
      ]);
    }
    // 6. Правый верхний угол левого нижнего квадрата
    for (int i = 1; i < 8; i++){
      result.add([
        (backgroundPictureSize - focusMarkerSize),
        (backgroundPictureSize * 2),
        0
      ]);
    }
    result.add([
      (backgroundPictureSize - focusMarkerSize),
      (backgroundPictureSize * 2),
      1
    ]);
    for (int i = 1; i < 8; i++){
      result.add([
        (backgroundPictureSize - focusMarkerSize),
        (backgroundPictureSize * 2),
        0
      ]);
    }
    // Путь от 6 к 7.
    for (int i = 1; i < 31; i++){
      result.add([
        ((backgroundPictureSize - focusMarkerSize)
            - ((backgroundPictureSize - focusMarkerSize) / 30 * i)),
        ((backgroundPictureSize * 2)
            + (backgroundPictureSize - focusMarkerSize) / 30 * i),
        0
      ]);
    }
    // 7. Левый нижний угол левого нижнего квадрата
    for (int i = 1; i < 8; i++){
      result.add([0, (backgroundPictureSize * 3 - focusMarkerSize), 0]);
    }
    result.add([0, (backgroundPictureSize * 3 - focusMarkerSize), 1]);
    for (int i = 1; i < 8; i++){
      result.add([0, (backgroundPictureSize * 3 - focusMarkerSize), 0]);
    }
    // Путь от 7 к 8.
    for (int i = 1; i < 31; i++){
      result.add([
        ((backgroundPictureSize * 2 - focusMarkerSize) / 30 * i),
        (backgroundPictureSize * 3 - focusMarkerSize),
        0
      ]);
    }
    // 8. Правый нижний угол правого нижнего квадрата
    for (int i = 1; i < 8; i++){
      result.add([
        (backgroundPictureSize * 2 - focusMarkerSize),
        (backgroundPictureSize * 3 - focusMarkerSize),
        0
      ]);
    }
    result.add([
      (backgroundPictureSize * 2 - focusMarkerSize),
      (backgroundPictureSize * 3 - focusMarkerSize),
      1
    ]);
    for (int i = 1; i < 8; i++){
      result.add([
        (backgroundPictureSize * 2 - focusMarkerSize),
        (backgroundPictureSize * 3 - focusMarkerSize),
        0
      ]);
    }
    // Путь от 8 к 9.
    for (int i = 1; i < 31; i++){
      result.add([
        ((backgroundPictureSize * 2 - focusMarkerSize)
            - ((backgroundPictureSize - focusMarkerSize) / 30 * i)),
        ((backgroundPictureSize * 3 - focusMarkerSize)
            - ((backgroundPictureSize - focusMarkerSize) / 30 * i)),
        0
      ]);
    }
    // 9. Левый верхний угол правого нижнего квадрата
    for (int i = 1; i < 8; i++){
      result.add([backgroundPictureSize, (backgroundPictureSize * 2), 0]);
    }
    result.add([backgroundPictureSize, (backgroundPictureSize * 2), 1]);
    for (int i = 1; i < 8; i++){
      result.add([backgroundPictureSize, (backgroundPictureSize * 2), 0]);
    }
    // Путь от 9 к 10.
    for (int i = 1; i < 31; i++){
      result.add([
        backgroundPictureSize,
        ((backgroundPictureSize * 2) - (focusMarkerSize / 30 * i)),
        0
      ]);
    }
    // 10. Левый нижний угол правого среднего квадрата
    for (int i = 1; i < 8; i++){
      result.add([
        backgroundPictureSize,
        (backgroundPictureSize * 2 - focusMarkerSize),
        0
      ]);
    }
    result.add([
      backgroundPictureSize,
      (backgroundPictureSize * 2 - focusMarkerSize),
      1
    ]);
    for (int i = 1; i < 8; i++){
      result.add([
        backgroundPictureSize,
        (backgroundPictureSize * 2 - focusMarkerSize),
        0
      ]);
    }
    // Путь от 10 к 11.
    for (int i = 1; i < 31; i++){
      result.add([
        (backgroundPictureSize
            + ((backgroundPictureSize - focusMarkerSize) / 30 * i)),
        ((backgroundPictureSize * 2 - focusMarkerSize)
            - ((backgroundPictureSize - focusMarkerSize) / 60 * i)),
        0
      ]);
    }
    // 11. Середина правой грани правого среднего квадрата
    for (int i = 1; i < 8; i++){
      result.add([
        (backgroundPictureSize * 2 - focusMarkerSize),
        (backgroundPictureSize + (backgroundPictureSize - focusMarkerSize) / 2),
        0
      ]);
    }
    result.add([
      (backgroundPictureSize * 2 - focusMarkerSize),
      (backgroundPictureSize + (backgroundPictureSize - focusMarkerSize) / 2),
      1
    ]);
    for (int i = 1; i < 8; i++){
      result.add([
        (backgroundPictureSize * 2 - focusMarkerSize),
        (backgroundPictureSize + (backgroundPictureSize - focusMarkerSize) / 2),
        0
      ]);
    }
    // Путь от 11 к 12.
    for (int i = 1; i < 31; i++){
      result.add([
        ((backgroundPictureSize * 2 - focusMarkerSize)
            - ((backgroundPictureSize - focusMarkerSize) / 30 * i)),
        ((backgroundPictureSize + (backgroundPictureSize - focusMarkerSize) / 2)
            - ((backgroundPictureSize - focusMarkerSize) / 60 * i)),
        0
      ]);
    }
    // 12. Левый верхний угол правого среднего квадрата
    for (int i = 1; i < 8; i++){
      result.add([backgroundPictureSize, backgroundPictureSize, 0]);
    }
    result.add([backgroundPictureSize, backgroundPictureSize, 1]);
    for (int i = 1; i < 8; i++){
      result.add([backgroundPictureSize, backgroundPictureSize, 0]);
    }
    // Путь от 12 к 13.
    for (int i = 1; i < 31; i++){
      result.add([
        backgroundPictureSize,
        (backgroundPictureSize - (focusMarkerSize / 30 * i)),
        0
      ]);
    }
    // 13. Левый нижний угол правого верхнего квадрата
    for (int i = 1; i < 8; i++){
      result.add([
        backgroundPictureSize,
        (backgroundPictureSize - focusMarkerSize),
        0
      ]);
    }
    result.add([
      backgroundPictureSize,
      (backgroundPictureSize - focusMarkerSize),
      1
    ]);
    for (int i = 1; i < 8; i++){
      result.add([
        backgroundPictureSize,
        (backgroundPictureSize - focusMarkerSize),
        0
      ]);
    }
    // Путь от 13 к 14.
    for (int i = 1; i < 31; i++){
      result.add([
        (backgroundPictureSize
            + ((backgroundPictureSize - focusMarkerSize) / 30 * i)),
        ((backgroundPictureSize - focusMarkerSize)
            - ((backgroundPictureSize - focusMarkerSize) / 30 * i)),
        0
      ]);
    }
    // 14. Правый верхний угол правого верхнего квадрата
    for (int i = 1; i < 8; i++){
      result.add([(backgroundPictureSize * 2 - focusMarkerSize), 0, 0]);
    }
    result.add([(backgroundPictureSize * 2 - focusMarkerSize), 0, 1]);
    for (int i = 1; i < 8; i++){
      result.add([(backgroundPictureSize * 2 - focusMarkerSize), 0, 0]);
    }
    return result;
  }

  /// Функция работы глазного трекера.
  Future<void>startEyeTracker(List<List<double>> list) async{
    Duration trackerDuration = const Duration(milliseconds: 100);
    for (int i = frameNumber; i < list.length;) {
      // Если не на паузе.
      //if (pauseTimer == 0) {
        i++;
        // if (screenState.timerCount == 0) {
        frameNumber = i;
        await Future.delayed(trackerDuration, () {
          createNewFrameNumber(frameNumber);
          if (list[frameNumber][2] == 1) {
            toSavePhoto = true;
          }
        });
     // }
    }
    // Если не выходит за границы допустимого диапазона.
    if (((distance >= lowerLimit) || (height >= lowerLimit))
        || ((distance <= upperLimit) || (height <= upperLimit))){
      Duration pauseDuration = const Duration(milliseconds: 1000);
      await Future.delayed(pauseDuration, () {
        pauseTimer--;
        eyeTrackerState = EyeTrackerState(
          frameNumber: frameNumber,
          pauseTimer: pauseTimer,
          isAppStop: isAppStop
        );
        eyeTrackerCtrl.add(eyeTrackerState);
      });
    }

    // // screenState = ScreenState(tilt, distance, 0, frameNumber, true);
    await Future.delayed(const Duration(milliseconds: 2000), () {
      stopApp();
    });
  }

  /// Переключает глазной треккер на следующий кадр.
  void createNewFrameNumber (int number){
    eyeTrackerState = EyeTrackerState(
      frameNumber: number,
      pauseTimer: pauseTimer,
      isAppStop: isAppStop
    );
    eyeTrackerCtrl.add(eyeTrackerState);
  }

  /// Останавливает сессию.
  // Future<void> stopApp ()async{
  void stopApp (){
    isAppStop = true;
    eyeTrackerState = EyeTrackerState(
      frameNumber: frameNumber,
      pauseTimer: pauseTimer,
      isAppStop: isAppStop
    );
    eyeTrackerCtrl.add(eyeTrackerState);
    // await _cameraCtrl.stopImageStream();
    _cameraCtrl.dispose();
    print('Остановка ${DateTime.now().second} ${DateTime.now().millisecond}');
  }

  /// Функция работы индикатора положения смартфона.
  Future<void>startPositionMarker() async{
    int index = 0;
    await _initializeControllerFuture;
    while (!isAppStop){
      index++;
      await makePhoto(index);
    }
  }

  Future<void> makePhoto(int index) async {
    try {
      print('№$index Cтрат фото для нейронки '
          '${DateTime.now().second} ${DateTime.now().millisecond}');
      final XFile photo = await _cameraCtrl.takePicture();
      print('№$index Фото сделано '
          '${DateTime.now().second} ${DateTime.now().millisecond}');
      dataPreparing(index, photo);
      print('№$index Конец фото для нейронки '
          '${DateTime.now().second} ${DateTime.now().millisecond}');
      if(toSavePhoto){
        toSavePhoto = false;
        photoNumber++;
        savePhoto(photoNumber, photo);
      }
    } catch(e){
      print('№$index Ошибка $e '
          '${DateTime.now().second} ${DateTime.now().millisecond}');
    }
  }

  /// Подготовка данных для позиции.
  Future<void> dataPreparing(int index, XFile photo) async {
    try {
      print('№$index Страт подготовки данных '
          '${DateTime.now().second} ${DateTime.now().millisecond}');
      if ((index - positionCount) > 2) {
        print('№$index Фото пропущено '
            '${DateTime.now().second} ${DateTime.now().millisecond}');
        return;
      }
      final File file = File(photo.path);
      // final img.Image? image = img.decodeImage(await file.readAsBytes())!;
      final img.Image resizedImage = img.copyResize(img.decodeImage(
        await file.readAsBytes())!,
        width: imgWidth,
        height: imgHeight
      );
      final List<int> biteList
          = resizedImage.getBytes(format: img.Format.rgb).toList();
      final List<double> pointsList = compressingArrayByThree(biteList);
      final List<List<double>> pointsMatrix = slicer(pointsList, imgWidth);
      print (pointsMatrix);
      final String encodedData = json.encode({"photo": pointsMatrix});
      getPosition(encodedData, "application/json", index);
      print('№$index Конец подготовки данных '
          '${DateTime.now().second} ${DateTime.now().millisecond}');
    } catch(e){
      print('№$index Ошибка $e '
          '${DateTime.now().second} ${DateTime.now().millisecond}');
    }
  }

  /// Групирует числа входящего массива по три подряд
  /// и возвращает массив средних арефметических этих чисел.
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
  List<List<double>> slicer (List<double> list, int size){
    int len = list.length;
    List<List<double>> result = [];
    for (int i = 0; i < len; i+= size){
      final end = (i + size < len)? i + size:len;
      result.add(list.sublist(i, end));
    }
    return result;
  }

  /// Посылает данные на сервер и возвращает ответ сервера.
  Future<void> getPosition(String forwardedData, String header, int index) async{
    print('№$index Начало получения позиции '
        '${DateTime.now().second} ${DateTime.now().millisecond}');
    try{
      http.Response postR = await client.post(
        Uri.https('qviz.fun', 'api/v1/get/predict/'),
        body: forwardedData,
        headers: {"content-type": header}
      );
      print('№$index Конец получения позиции '
          '${DateTime.now().second} ${DateTime.now().millisecond}');
      print('№$index Позиция ${utf8.decode(postR.bodyBytes)}, $postR');
      // Проверка, что сервер возвращает ответы по-порядку,
      // иначе ответы отбрасываются.
      if (index > positionCount){
        final Map<String, dynamic> json
            = jsonDecode(utf8.decode(postR.bodyBytes));
        positionCount = index;
        height = json["sensor"] as double;
        distance = json["distance"] as double;
        if (((distance < lowerLimit) || (height < lowerLimit))
            || ((distance > upperLimit) || (height > upperLimit))){
          pauseTimer = 3;
          eyeTrackerState = EyeTrackerState(
            frameNumber: frameNumber,
            pauseTimer: pauseTimer,
            isAppStop: isAppStop
          );
          eyeTrackerCtrl.add(eyeTrackerState);
        }
        positionMarkerState = PositionMarkerState(
          count: positionCount,
          height: height,
          distance: distance
        );
        positionMarkerStreamCtrl.add(positionMarkerState);
      }
    }catch(e){
      print('№$index Ошибка $e '
          '${DateTime.now().second} ${DateTime.now().millisecond}');
    }
  }

  /// Сохранение фото.
  Future<void>savePhoto(int number, XFile photo) async{
    await ImageGallerySaver.saveImage(
      await photo.readAsBytes(),
      name: "photo №$number"
    );
  }


}

/// Класс состояния глазного трекера.
class EyeTrackerState{

  final int frameNumber;
  final int pauseTimer;
  final bool isAppStop;

  EyeTrackerState({
    required this.frameNumber,
    required this.pauseTimer,
    required this.isAppStop
  });

}

/// Класс состояния индикатора положения смартфона.
class PositionMarkerState{

  final int count;
  final double height;
  final double distance;

  PositionMarkerState({
    required this.count,
    required this.height,
    required this.distance
  });

}
