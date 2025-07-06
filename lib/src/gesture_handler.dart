import 'package:flutter/widgets.dart';

abstract class PdfGestureStrategy {
  bool get panEnabled;
  bool get scaleEnabled;
  void onPointerDown(PointerDownEvent event);
  void onPointerUp(PointerUpEvent event);
  void onDoubleTap(TransformationController controller, Offset position);
}

class MobileGestureStrategy implements PdfGestureStrategy {
  @override
  final bool panEnabled = true;
  
  @override
  final bool scaleEnabled = true;

  @override
  void onPointerDown(PointerDownEvent event) {}

  @override
  void onPointerUp(PointerUpEvent event) {}

  @override
  void onDoubleTap(TransformationController controller, Offset position) {
    final double targetScale = 2.5;
    final currentMatrix = controller.value;

    if (currentMatrix != Matrix4.identity()) {
      controller.value = Matrix4.identity();
    } else {
      final x = -position.dx * (targetScale - 1);
      final y = -position.dy * (targetScale - 1);
      controller.value = Matrix4.identity()
        ..translate(x, y)
        ..scale(targetScale);
    }
  }
}

class DesktopGestureStrategy implements PdfGestureStrategy {
  @override
  final bool panEnabled = false;
  
  @override
  final bool scaleEnabled = false;

  @override
  void onPointerDown(PointerDownEvent event) {}

  @override
  void onPointerUp(PointerUpEvent event) {}

  @override
  void onDoubleTap(TransformationController controller, Offset position) {
    // No-op for desktop since pan/scale are disabled
  }
}

class GestureHandler {
  final PdfGestureStrategy _strategy;
  final TransformationController _transformationController;
  Offset _lastTapPosition = Offset.zero;

  GestureHandler({
    required bool isMobile,
    required TransformationController transformationController,
  })  : _strategy = isMobile ? MobileGestureStrategy() : DesktopGestureStrategy(),
        _transformationController = transformationController;

  void onPointerDown(PointerDownEvent event) => _strategy.onPointerDown(event);
  void onPointerUp(PointerUpEvent event) => _strategy.onPointerUp(event);

  void onDoubleTap() {
    _strategy.onDoubleTap(_transformationController, _lastTapPosition);
  }

  InteractiveViewer buildInteractiveViewer({
    required Widget child,
    double maxScale = 5.0,
    double minScale = 1.0,
  }) {
    return InteractiveViewer(
      transformationController: _transformationController,
      panEnabled: _strategy.panEnabled,
      scaleEnabled: _strategy.scaleEnabled,
      maxScale: maxScale,
      minScale: minScale,
      child: GestureDetector(
        onDoubleTap: onDoubleTap,
        onTapDown: (details) => _lastTapPosition = details.localPosition,
        child: child,
      ),
    );
  }
}