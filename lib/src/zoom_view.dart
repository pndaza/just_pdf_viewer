import 'package:flutter/widgets.dart';

/// A reusable widget that provides zoom and gesture capabilities
class ZoomView extends StatefulWidget {
  final Widget child;
  final double minScale;
  final double maxScale;
  final bool isMobile;
  final ValueChanged<Matrix4>? onTransformationChanged;

  const ZoomView({
    Key? key,
    required this.child,
    this.minScale = 1.0,
    this.maxScale = 5.0,
    required this.isMobile,
    this.onTransformationChanged,
  }) : super(key: key);

  @override
  State<ZoomView> createState() => _ZoomViewState();
}

class _ZoomViewState extends State<ZoomView> {
  late TransformationController _transformationController;
  Offset _lastTapPosition = Offset.zero;

  @override
  void initState() {
    super.initState();
    _transformationController = TransformationController();
    _transformationController.addListener(() {
      widget.onTransformationChanged?.call(_transformationController.value);
    });
  }

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  void _onDoubleTap() {
    if (!widget.isMobile) return;

    final double targetScale = 2.5;
    final currentMatrix = _transformationController.value;

    if (currentMatrix != Matrix4.identity()) {
      _transformationController.value = Matrix4.identity();
    } else {
      final x = -_lastTapPosition.dx * (targetScale - 1);
      final y = -_lastTapPosition.dy * (targetScale - 1);
      _transformationController.value = Matrix4.identity()
        ..translate(x, y)
        ..scale(targetScale);
    }
  }

  @override
  Widget build(BuildContext context) {
    return InteractiveViewer(
      transformationController: _transformationController,
      panEnabled: widget.isMobile,
      scaleEnabled: widget.isMobile,
      maxScale: widget.maxScale,
      minScale: widget.minScale,
      child: GestureDetector(
        onDoubleTap: _onDoubleTap,
        onTapDown: (details) => _lastTapPosition = details.localPosition,
        child: widget.child,
      ),
    );
  }
}