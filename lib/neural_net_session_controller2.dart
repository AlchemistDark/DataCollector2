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

  final String serverAddress = 'https://qviz.fun/api/v1/get/predict/';

  final http.Client client = http.Client();

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
  Uint8List? lastPhoto;
  CameraImage? currentImage;
  img.Image? lastImage;

  ScreenState screenState = ScreenState(-1, -1, null, null, 30, 0, false, '');

  late CameraController _cameraCtrl;
  late Future<void> _initializeControllerFuture;
  //late final List<List<double>> focusMarkerPaddingList;

  ///Todo
  Stream<ScreenState> get positionState => positionStateCtrl.stream;
  final StreamController<ScreenState> positionStateCtrl = StreamController<ScreenState>.broadcast();

  NeuralNetSessionController({
    required this.camera
  }){
    _cameraCtrl = CameraController(
      camera,
      ResolutionPreset.low,
      imageFormatGroup: ImageFormatGroup.yuv420
    );
    _initializeControllerFuture = _cameraCtrl.initialize();
    _cameraCtrl.setFocusMode(FocusMode.locked);
    takePhotoCycle();
  }

  Future<void> neuralNetModeStop() async{
    await _cameraCtrl.stopImageStream();
    _cameraCtrl.dispose();
  }


  Future<void> takePhotoCycle2() async{
    await _cameraCtrl.initialize().then((_) => print("начало 111"));
    await _cameraCtrl.setFocusMode(FocusMode.locked).then((_) => print("начало 222"));
    await _cameraCtrl.startImageStream((image) {
      print("начало 333");
      currentImage = image;
    });
    Duration duration = const Duration(milliseconds: 1000);
    // for (int i = 0; i < 30; i++){
    //   if (i == 15) {
    //     await Future.delayed(duration, () {
    //       // makePhotoForGetPositionAndSave(i);
    //     });
    //   }else{
        await Future.delayed(duration, () {
          makePhotoForGetPositionOnly2(1);
        });
      // }
    // }
    screenState = ScreenState(tilt, distance, lastPhoto, lastImage, timerCount, frameNumber, isStop, log);
    positionStateCtrl.add(screenState);
    neuralNetModeStop();
  }

  Future<void> takePhotoCycle() async{
    await _initializeControllerFuture;
    for (int i = 0; i < 30; i++){
      if (i == 15) {
        await makePhotoForGetPositionAndSave(i);
      }else{
        await makePhotoForGetPositionOnly(i);
      }
      neuralNetModeStop();
    }
    screenState = ScreenState(tilt, distance, lastPhoto, lastImage, timerCount, frameNumber, isStop, log);
    positionStateCtrl.add(screenState);
  }

  Future<void> makePhotoForGetPositionOnly2(int index) async {
    print('$index Страт фото для позиции ${DateTime.now().second} ${DateTime.now().millisecond}');
    log = "$log /n $index Страт фото для позиции ${DateTime.now().second} ${DateTime.now().millisecond}";
    if(currentImage != null){
      print("не нуль");

      //CameraPreview

      // img.Image _convertBGRA8888(CameraImage image) {
      //   return img.Image.fromBytes(
      //     image.width,
      //     image.height,
      //     image.planes[1].bytes,
      //     format: img.Format.bgra,
      //   );
      // }
      //lastPhoto = currentImage!.planes[0].bytes;

      ByteBuffer byteBuffer = convertYUV420ToImage(currentImage!).data.buffer;
      // Uint32List thirtytwoBitList = byteBuffer.asUint32List();
      // print(thirtytwoBitList);
      lastPhoto = byteBuffer.asUint8List();
      lastImage = convertYUV420ToImage(currentImage!);

      screenState = ScreenState(tilt, distance, lastPhoto, lastImage, timerCount, frameNumber, isStop, log);
      positionStateCtrl.add(screenState);


      try{
        await ImageGallerySaver.saveImage(await lastPhoto!.buffer.asUint8List(), name: "photo");
        print("сохранено");
      }catch(e){
        print("ошибка $e");
      }
    }
    print('$index Сделано фото для позиции ${DateTime.now().second} ${DateTime.now().millisecond}');
    log = "$log /n $index Сделано фото для позиции ${DateTime.now().second} ${DateTime.now().millisecond}";
  }

  // Future<File> imageToFile(String imageName, String ext) async {
  //   var bytes = await rootBundle.load('assets/$imageName.$ext');
  //   String tempPath = (await getTemporaryDirectory()).path;
  //   File file = File('$tempPath/profile.png');
  //   await file.writeAsBytes(
  //       bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes));
  //   return file;
  // }

  InputImage _convertCameraImageToInputImage(CameraImage cameraImage) {
    InputImageFormat? inputImageFormat;
    // switch (cameraImage.format.group) {
    //   case ImageFormatGroup.yuv420:
    //     if (Platform.isAndroid) {
    //       inputImageFormat = InputImageFormat.yuv_420_888;
    //     }
    //     if (Platform.isIOS) {
    //       inputImageFormat = InputImageFormat.yuv420;
    //     }
    //     break;
    //   case ImageFormatGroup.bgra8888:
        inputImageFormat = InputImageFormat.YUV420;
    //     break;
    // }

    if (inputImageFormat == null) {
      throw Exception("InputImageFormat is null");
    }

    InputImagePlaneMetadata inputImagePlaneMetadata = InputImagePlaneMetadata(
        bytesPerRow: cameraImage.planes[0].bytesPerRow,
        height: cameraImage.planes[0].height,
        width: cameraImage.planes[0].width);
    InputImageData inputImageData = InputImageData(
        size: Size(cameraImage.width.toDouble(), cameraImage.height.toDouble()),
        imageRotation: InputImageRotation.Rotation_0deg,
        inputImageFormat: inputImageFormat,
        planeData: [inputImagePlaneMetadata]);
    return InputImage.fromBytes(
        bytes: cameraImage.planes[1].bytes, inputImageData: inputImageData);
  }

  Future<void> makePhotoForGetPositionOnly(int index) async {
    _cameraCtrl.setFocusMode(FocusMode.locked);
    try {
      print('$index Страт фото для позиции ${DateTime.now().second} ${DateTime.now().millisecond}');
      log = "$log /n $index Страт фото для позиции ${DateTime.now().second} ${DateTime.now().millisecond}";
      //await _initializeControllerFuture;
      print('$index Конец инициализации для позиции ${DateTime.now().second} ${DateTime.now().millisecond}');
      log = "$log /n $index Конец инициализации для позиции ${DateTime.now().second} ${DateTime.now().millisecond}";
      final XFile photo = await _cameraCtrl.takePicture();

      print('$index Сделано фото для позиции ${DateTime.now().second} ${DateTime.now().millisecond}');
      log = "$log /n $index Сделано фото для позиции ${DateTime.now().second} ${DateTime.now().millisecond}";
      final File file = File(photo.path);
      final img.Image resizedPhoto = img.copyResize(img.decodeImage(await file.readAsBytes())!, width: imgWidth, height: imgHeight);
      final List<int> biteList = resizedPhoto.data;  // .getBytes(format: img.Format.rgb).toList();

      lastPhoto = await photo.readAsBytes();
      screenState = ScreenState(tilt, distance, lastPhoto, lastImage, timerCount, frameNumber, isStop, log);
      positionStateCtrl.add(screenState);

      final List<double> pointsList = compressingArrayByThree(biteList);
      final List<List<double>> pointsMatrix = sliceArray(pointsList, imgWidth);
      print (pointsMatrix);
      getPosition2(pointsMatrix, "application/json", index);
      //getPosition(pointsMatrix, index);
      print('$index Конец фото для позиции ${DateTime.now().second} ${DateTime.now().millisecond}');
      log = "$log /n $index Конец фото для позиции ${DateTime.now().second} ${DateTime.now().millisecond}";
    } catch(e){
      print("$index Ошибка фото для позиции $e");
      log = "$log /n $index Ошибка фото для позиции $e";
    }
  }

  Future<void> makePhotoForGetPositionAndSave(int index) async{
    _cameraCtrl.setFocusMode(FocusMode.auto);
    try {
      print('$index Страт фото для сохранения ${DateTime.now().second} ${DateTime.now().millisecond}');
      log = "$log /n $index Страт фото для сохранения ${DateTime.now().second} ${DateTime.now().millisecond}";
      await _initializeControllerFuture;
      final XFile photo = await _cameraCtrl.takePicture();
      print('$index Сделано фото для сохранения ${DateTime.now().second} ${DateTime.now().millisecond}');
      log = "$log /n $index Сделано фото для сохранения ${DateTime.now().second} ${DateTime.now().millisecond}";
      final File file = File(photo.path);
      final img.Image resizedPhoto = img.copyResize(img.decodeImage(await file.readAsBytes())!, width: imgWidth, height: imgHeight);
      final List<int> biteList = resizedPhoto.getBytes(format: img.Format.rgb).toList();

      lastPhoto = await photo.readAsBytes();
      screenState = ScreenState(tilt, distance, lastPhoto, lastImage, timerCount, frameNumber, isStop, log);
      positionStateCtrl.add(screenState);

      final List<double> pointsList = compressingArrayByThree(biteList);
      final List<List<double>> pointsMatrix = sliceArray(pointsList, imgWidth);
      print (pointsMatrix);
      getPosition2(pointsMatrix, "application/json", index);
      //getPosition(pointsMatrix, index);
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
    _cameraCtrl.setFocusMode(FocusMode.locked);
  }


  static img.Image convertYUV420ToImage(CameraImage cameraImage) {
    final width = cameraImage.width;
    final height = cameraImage.height;

    final yRowStride = cameraImage.planes[0].bytesPerRow;
    final uvRowStride = cameraImage.planes[1].bytesPerRow;
    final uvPixelStride = cameraImage.planes[1].bytesPerPixel!;

    final image = img.Image(width, height);

    for (var w = 0; w < width; w++) {
      for (var h = 0; h < height; h++) {
        final uvIndex =
            uvPixelStride * (w / 2).floor() + uvRowStride * (h / 2).floor();
        final index = h * width + w;
        final yIndex = h * yRowStride + w;

        final y = cameraImage.planes[0].bytes[yIndex];
        final u = cameraImage.planes[1].bytes[uvIndex];
        final v = cameraImage.planes[2].bytes[uvIndex];

        image.data[index] = yuv2rgb(y, u, v);
      }
    }
    return image;
  }

  static int yuv2rgb(int y, int u, int v) {
    // Convert yuv pixel to rgb
    var r = (y + v * 1436 / 1024 - 179).round();
    var g = (y - u * 46549 / 131072 + 44 - v * 93604 / 131072 + 91).round();
    var b = (y + u * 1814 / 1024 - 227).round();

    // Clipping RGB values to be inside boundaries [ 0 , 255 ]
    r = r.clamp(0, 255);
    g = g.clamp(0, 255);
    b = b.clamp(0, 255);

    return 0xff000000 |
    ((b << 16) & 0xff0000) |
    ((g << 8) & 0xff00) |
    (r & 0xff);
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

  /// Посылает данные на сервер и возвращает ответ сервера.
  Future<void> getPosition3(Object forwardedData, String header, int index) async{
    final String encodedData = json.encode({"photo": forwardedData});

    print('$index Начало низкоуровневого2 получения позиции ${DateTime.now().second} ${DateTime.now().millisecond}');
    log = "$log /n $index Начало низкоуровневого2 получения позиции ${DateTime.now().second} ${DateTime.now().millisecond}";

    try{
      var result = await http.post(
        Uri.https('qviz.fun', 'api/v1/get/predict/'),
        body: encodedData,
        headers: {"content-type": header}
      );
      print('$index Конец низкоуровневого2 получения позиции ${DateTime.now().second} ${DateTime.now().millisecond}');
      log = "$log /n $index Конец низкоуровневого2 получения позиции ${DateTime.now().second} ${DateTime.now().millisecond}";
      //String responseAnswer = utf8.decode(postR.bodyBytes);


      print("$index Позиция ${result.body.toString()} ${result.body} ${result.bodyBytes.toString()} ${utf8.decode(result.bodyBytes)}, ${result.bodyBytes}");
      log = "$log /n $index Позиция ${result.body.toString()} ${result.body} ${result.bodyBytes.toString()} ${utf8.decode(result.bodyBytes)}, ${result.bodyBytes}";
      //final Map<String, dynamic> json = jsonDecode(utf8.decode(postR.bodyBytes));
      // final Map<String, dynamic> json = response.data;
      // tilt = json["sensor"] as double;
      // distance = json["distance"] as double;
      screenState = ScreenState(tilt, distance, lastPhoto, lastImage, timerCount, frameNumber, isStop, log);
      positionStateCtrl.add(screenState);


    }catch(e){
      print(e);
      log = "$log /n $e";
    }

  }

  /// Посылает данные на сервер и возвращает ответ сервера.
  Future<void> getPosition2(Object forwardedData, String header, int index) async{
    final String encodedData = json.encode({"photo": forwardedData});

    print('$index Начало низкоуровневого получения позиции ${DateTime.now().second} ${DateTime.now().millisecond}');
    log = "$log /n $index Начало низкоуровневого получения позиции ${DateTime.now().second} ${DateTime.now().millisecond}";

    try{
      http.Response postR = await client.post(
        Uri.https('qviz.fun', 'api/v1/get/predict/'),
        body: encodedData,
        headers: {"content-type": header}
      );
      print('$index Конец низкоуровневого получения позиции ${DateTime.now().second} ${DateTime.now().millisecond}');
      log = "$log /n $index Конец низкоуровневого получения позиции ${DateTime.now().second} ${DateTime.now().millisecond}";
      //String responseAnswer = utf8.decode(postR.bodyBytes);


      print("$index Позиция ${utf8.decode(postR.bodyBytes)}, $postR");
      log = "$log /n $index Позиция ${utf8.decode(postR.bodyBytes)}, $postR";
      final Map<String, dynamic> json = jsonDecode(utf8.decode(postR.bodyBytes));
      // final Map<String, dynamic> json = response.data;
      tilt = json["sensor"] as double;
      distance = json["distance"] as double;
      screenState = ScreenState(tilt, distance, lastPhoto, lastImage, timerCount, frameNumber, isStop, log);
      positionStateCtrl.add(screenState);


    }catch(e){
      print(e);
      log = "$log /n $e";
    }

  }

  /// Посылает данные на сервер и  и возвращает ответ сервера используя Dio.
  Future<void> getPosition(Object forwardedData, int index) async{
    print('$index Начало получения позиции ${DateTime.now().second} ${DateTime.now().millisecond}');
    log = "$log /n $index Начало получения позиции ${DateTime.now().second} ${DateTime.now().millisecond}";
    try {
      Response response = await Dio().post(
        serverAddress,
        data: {"photo": forwardedData});
      print('$index Конец получения позиции ${DateTime.now().second} ${DateTime.now().millisecond}');
      log = "$log /n $index Конец получения позиции ${DateTime.now().second} ${DateTime.now().millisecond}";
      print("$index Позиция ${response.data}");
      log = "$log /n $index Позиция ${response.data}";

      final Map<String, dynamic> json = response.data;
      tilt = json["sensor"] as double;
      distance = json["distance"] as double;
      screenState = ScreenState(tilt, distance, lastPhoto, lastImage, timerCount, frameNumber, isStop, log);
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

  final Uint8List? lastPhoto;
  final img.Image? lastImage;

  final int timerCount;
  final int frameNumber;
  final bool isStop;
  final String log;

  ScreenState(this.tilt, this.distance, this.lastPhoto, this.lastImage, this.timerCount, this.frameNumber, this.isStop, this.log);

}