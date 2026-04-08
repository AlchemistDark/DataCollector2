import 'dart:async';
import 'dart:convert';
import 'dart:isolate';

import 'package:camera/camera.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:http/http.dart' as http;

import 'package:data_collector2/domain/entities/session_class.dart';
import 'package:data_collector2/data/services/camera_stream_worker.dart';

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

  /// Порт для отправки задач воркеру в Isolate.
  SendPort? _workerSendPort;
  /// Флаг, что воркер сейчас занят обработкой кадра.
  bool _isProcessing = false;
  /// Индекс текущего потокового кадра.
  int _streamIndex = 0;

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
      imageFormatGroup: ImageFormatGroup.yuv420,
      enableAudio: false,
    );
    _initializeControllerFuture = _cameraCtrl.initialize();
    _cameraCtrl.setFocusMode(FocusMode.locked);
    _initIsolate();
  }

  /// Инициализация воркера в Isolate.
  Future<void> _initIsolate() async {
    final receivePort = ReceivePort();
    await Isolate.spawn(cameraImageWorker, receivePort.sendPort);

    // Первым сообщением воркер присылает свой SendPort.
    final firstMessage = await receivePort.first;
    if (firstMessage is SendPort) {
      _workerSendPort = firstMessage;
      
      // Слушаем результаты от воркера.
      receivePort.listen((message) {
        if (message is CameraStreamResult) {
          _handleWorkerResult(message);
        }
      });
    }
  }

  /// Обработка результата из Isolate.
  Future<void> _handleWorkerResult(CameraStreamResult result) async {
    _isProcessing = false;

    // 1. Отправка матрицы на сервер для предсказания.
    if (result.matrix != null) {
      final String encodedData = json.encode({"photo": result.matrix});
      getPosition(encodedData, "application/json", _streamIndex);
    }

    // 2. Сохранение фото, если это было запрошено.
    if (result.jpegBytes != null && result.photoNumber != null) {
      await ImageGallerySaverPlus.saveImage(
        result.jpegBytes!,
        name: "photo №${result.photoNumber}"
      );
    }
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
    for (int i = frameNumber; i < (list.length - 1);) {
        await Future.delayed(trackerDuration, () {
          createNewFrameNumber(frameNumber);
          if (list[frameNumber][2] == 1) {
            toSavePhoto = true;
          }
        });
        i++;
        frameNumber = i;
    }
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
  void stopApp (){
    isAppStop = true;
    eyeTrackerState = EyeTrackerState(
      frameNumber: frameNumber,
      pauseTimer: pauseTimer,
      isAppStop: isAppStop
    );
    eyeTrackerCtrl.add(eyeTrackerState);
    _cameraCtrl.dispose();
    print('Остановка ${DateTime.now().second} ${DateTime.now().millisecond}');
  }

  /// Функция работы индикатора положения смартфона (теперь через ImageStream).
  Future<void> startPositionMarker() async {
    await _initializeControllerFuture;
    
    _cameraCtrl.startImageStream((CameraImage image) {
      if (isAppStop) return;
      _onImageFrame(image);
    });
  }

  /// Обработка каждого кадра из потока.
  void _onImageFrame(CameraImage image) {
    if (_workerSendPort == null || _isProcessing) return;

    _isProcessing = true;
    _streamIndex++;

    // Подготавливаем задачу для воркера.
    final task = CameraStreamTask(
      planes: image.planes.map((p) => p.bytes).toList(),
      width: image.width,
      height: image.height,
      targetWidth: imgWidth,
      targetHeight: imgHeight,
      saveAsQuality: toSavePhoto,
      photoNumber: toSavePhoto ? ++photoNumber : null,
    );

    // Сбрасываем флаг сохранения, так как мы уже "захватили" кадр.
    if (toSavePhoto) {
      toSavePhoto = false;
    }

    _workerSendPort!.send(task);
  }

  // Старые методы makePhoto и dataPreparing больше не нужны, так как логика в Isolate.


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
    await ImageGallerySaverPlus.saveImage(
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
