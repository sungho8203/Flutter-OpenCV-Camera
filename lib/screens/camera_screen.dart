import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:opencv_4/opencv_4.dart';
import 'package:opencv_4/factory/pathfrom.dart';
import 'package:permission_handler/permission_handler.dart';
import '../painters/object_painter.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => CameraScreenState();
}

class CameraScreenState extends State<CameraScreen> {
  CameraController? _controller;
  bool _isDetecting = false;
  List<dynamic>? _detectedObjects;

  @override
  void initState() {
    super.initState();
    _requestCameraPermission();
  }

  Future<void> _requestCameraPermission() async {
    final status = await Permission.camera.request();
    if (status.isGranted) {
      _initializeCamera();
    } else {
      // 권한 거부 시 사용자에게 알림 필요
    }
  }

  Future<void> _initializeCamera() async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) return;

    final firstCamera = cameras.first;

    _controller = CameraController(
      firstCamera,
      ResolutionPreset.medium,
      enableAudio: false,
    );

    try {
      await _controller!.initialize();
      if (mounted) {
        setState(() {});
        _startObjectDetection();
      }
    } catch (e) {
      print('카메라 초기화 오류: $e');
    }
  }

  void _startObjectDetection() {
    _controller?.startImageStream((CameraImage image) async {
      if (_isDetecting) return;

      _isDetecting = true;
      try {
        final objects = await _detectObjects(image);
        if (mounted) {
          setState(() {
            _detectedObjects = objects;
          });
        }
        await Future.delayed(const Duration(seconds: 1));
      } catch (e) {
        print('물체 검출 오류: $e');
      } finally {
        _isDetecting = false;
      }
    });
  }

  Future<List<dynamic>> _detectObjects(CameraImage image) async {
    try {
      // YUV에서 BGR로 변환
      final bytes = await Cv2.cvtColor(
        pathFrom: CVPathFrom.GALLERY_CAMERA,
        pathString: base64Encode(image.planes[0].bytes),
        outputType: Cv2.COLOR_YUV2BGR_NV21,
      ) as String;

      // 이미지 전처리
      final processed = await _preprocessImage(bytes);

      // 물체 검출
      final contours = await Cv2.threshold(
        pathFrom: CVPathFrom.GALLERY_CAMERA,
        pathString: processed,
        thresholdValue: 128,
        maxThresholdValue: 255,
        thresholdType: Cv2.THRESH_BINARY,
      ) as String;

      return [contours];
    } catch (e) {
      print('물체 검출 오류: $e');
      return [];
    }
  }

  Future<String> _preprocessImage(String input) async {
    // 그레이스케일 변환
    final gray = await Cv2.cvtColor(
      pathFrom: CVPathFrom.GALLERY_CAMERA,
      pathString: input,
      outputType: Cv2.COLOR_BGR2GRAY,
    ) as String;

    // 가우시안 블러
    final blurred = await Cv2.gaussianBlur(
      pathFrom: CVPathFrom.GALLERY_CAMERA,
      pathString: gray,
      kernelSize: [5.0, 5.0],
      sigmaX: 0.0,
    ) as String;

    // 캐니 엣지 검출
    final edges = await Cv2.sobel(
      pathFrom: CVPathFrom.GALLERY_CAMERA,
      pathString: blurred,
      depth: -1,
      dx: 1,
      dy: 1,
    ) as String;

    return edges;
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null || !_controller!.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    return Stack(
      children: [
        CameraPreview(_controller!),
        if (_detectedObjects != null)
          CustomPaint(
            painter: ObjectPainter(_detectedObjects!, _controller!.value),
            size: MediaQuery.of(context).size,
          ),
      ],
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }
}
