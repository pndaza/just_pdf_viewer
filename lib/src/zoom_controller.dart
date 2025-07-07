import 'package:flutter/material.dart';

class ZoomController extends ChangeNotifier {
  TransformationController? _transformationController;
  void Function(Matrix4)? animateTo;
  
  double _minScale = 1.0;
  double _maxScale = 5.0;
  double _currentScale = 1.0;
  Size? _contentSize;
  Size? _viewportSize;

  // Getters
  TransformationController get transformationController {
    _transformationController ??= TransformationController();
    return _transformationController!;
  }

  double get currentScale => _currentScale;
  double get minScale => _minScale;
  double get maxScale => _maxScale;
  Size? get contentSize => _contentSize;
  Size? get viewportSize => _viewportSize;

  // Setters
  void setScaleConstraints({double? minScale, double? maxScale}) {
    if (minScale != null) _minScale = minScale;
    if (maxScale != null) _maxScale = maxScale;
    notifyListeners();
  }

  void setContentSize(Size size) {
    _contentSize = size;
  }

  void setViewportSize(Size size) {
    _viewportSize = size;
  }

  // Scale the content to a specific level
  void setScale(double scale, {Offset? focalPoint}) {
    final clampedScale = scale.clamp(_minScale, _maxScale);
    
    Matrix4 matrix;
    if (focalPoint != null && _viewportSize != null) {
      // Scale around focal point
      final x = -focalPoint.dx * (clampedScale - 1);
      final y = -focalPoint.dy * (clampedScale - 1);
      matrix = Matrix4.identity()
        ..translate(x, y)
        ..scale(clampedScale);
    } else {
      // Scale from center
      matrix = Matrix4.identity()..scale(clampedScale);
    }

    _applyTransformation(matrix);
    _currentScale = clampedScale;
    notifyListeners();
  }

  // Zoom in by a step
  void zoomIn({double step = 0.25}) {
    final newScale = (_currentScale + step).clamp(_minScale, _maxScale);
    setScale(newScale);
  }

  // Zoom out by a step
  void zoomOut({double step = 0.25}) {
    final newScale = (_currentScale - step).clamp(_minScale, _maxScale);
    setScale(newScale);
  }

  // Reset to original scale
  void reset() {
    _applyTransformation(Matrix4.identity());
    _currentScale = 1.0;
    notifyListeners();
  }

  // Fit content to viewport width
  void fitToWidth() {
    if (_contentSize == null || _viewportSize == null) return;
    
    final scale = _viewportSize!.width / _contentSize!.width;
    final clampedScale = scale.clamp(_minScale, _maxScale);
    
    final matrix = Matrix4.identity()..scale(clampedScale);
    _applyTransformation(matrix);
    _currentScale = clampedScale;
    notifyListeners();
  }

  // Fit content to viewport height
  void fitToHeight() {
    if (_contentSize == null || _viewportSize == null) return;
    
    final scale = _viewportSize!.height / _contentSize!.height;
    final clampedScale = scale.clamp(_minScale, _maxScale);
    
    final matrix = Matrix4.identity()..scale(clampedScale);
    _applyTransformation(matrix);
    _currentScale = clampedScale;
    notifyListeners();
  }

  // Fit content to viewport (best fit)
  void fitToScreen() {
    if (_contentSize == null || _viewportSize == null) return;
    
    final scaleX = _viewportSize!.width / _contentSize!.width;
    final scaleY = _viewportSize!.height / _contentSize!.height;
    final scale = (scaleX < scaleY ? scaleX : scaleY);
    final clampedScale = scale.clamp(_minScale, _maxScale);
    
    final matrix = Matrix4.identity()..scale(clampedScale);
    _applyTransformation(matrix);
    _currentScale = clampedScale;
    notifyListeners();
  }

  // Center the content in the viewport
  void centerContent() {
    if (_contentSize == null || _viewportSize == null) return;
    
    final scaledWidth = _contentSize!.width * _currentScale;
    final scaledHeight = _contentSize!.height * _currentScale;
    
    final x = (_viewportSize!.width - scaledWidth) / 2;
    final y = (_viewportSize!.height - scaledHeight) / 2;
    
    final matrix = Matrix4.identity()
      ..translate(x, y)
      ..scale(_currentScale);
    
    _applyTransformation(matrix);
    notifyListeners();
  }

  // Pan to a specific offset
  void panTo(Offset offset) {
    final matrix = Matrix4.identity()
      ..translate(offset.dx, offset.dy)
      ..scale(_currentScale);
    
    _applyTransformation(matrix);
    notifyListeners();
  }

  // Get current pan offset
  Offset getCurrentPanOffset() {
    final matrix = transformationController.value;
    return Offset(matrix.getTranslation().x, matrix.getTranslation().y);
  }

  // Update current scale from transformation matrix
  void updateScaleFromMatrix() {
    final matrix = transformationController.value;
    final scaleX = matrix.getMaxScaleOnAxis();
    if (scaleX != _currentScale) {
      _currentScale = scaleX;
      notifyListeners();
    }
  }

  // Apply transformation with animation support
  void _applyTransformation(Matrix4 matrix) {
    if (animateTo != null) {
      animateTo!(matrix);
    } else {
      transformationController.value = matrix;
    }
  }

  @override
  void dispose() {
    _transformationController?.dispose();
    super.dispose();
  }
}