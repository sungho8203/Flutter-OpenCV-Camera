import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'dart:math'; // min, max 함수 사용을 위해

class ObjectPainter extends CustomPainter {
  final List<dynamic> objects;
  final CameraValue cameraValue;

  ObjectPainter(this.objects, this.cameraValue);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.green
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    for (final object in objects) {
      // 좌표 변환 (카메라 해상도 -> 화면 크기)
      final rect = _transformRect(object, size);
      canvas.drawRect(rect, paint);
    }
  }

  Rect _transformRect(List<dynamic> points, Size size) {
    // OpenCV 좌표를 화면 좌표로 변환
    double minX = double.infinity;
    double minY = double.infinity;
    double maxX = -double.infinity;
    double maxY = -double.infinity;

    for (final point in points) {
      final x = point[0].toDouble();
      final y = point[1].toDouble();

      minX = min(minX, x);
      minY = min(minY, y);
      maxX = max(maxX, x);
      maxY = max(maxY, y);
    }

    // 카메라 해상도에서 화면 크기로 변환
    final scaleX = size.width / cameraValue.previewSize!.height;
    final scaleY = size.height / cameraValue.previewSize!.width;

    return Rect.fromLTRB(
      minX * scaleX,
      minY * scaleY,
      maxX * scaleX,
      maxY * scaleY,
    );
  }

  @override
  bool shouldRepaint(ObjectPainter oldDelegate) => true;
}
