import 'dart:math' as math;
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'zoom_controller.dart';

/// A reusable widget that provides zoom and gesture capabilities
class ZoomView extends StatefulWidget {
  final Widget child;
  final double minScale;
  final double maxScale;
  final bool isMobile;
  final ValueChanged<Matrix4>? onTransformationChanged;
  final double initialScale;
  final ZoomController? controller;

  const ZoomView({
    super.key,
    required this.child,
    this.minScale = 1.0,
    this.maxScale = 5.0,
    required this.isMobile,
    this.onTransformationChanged,
    this.controller,
    this.initialScale = 1.0,
  });

  @override
  State<ZoomView> createState() => _ZoomViewState();
}

class _ZoomViewState extends State<ZoomView> with TickerProviderStateMixin {
  late TransformationController _transformationController;
  late AnimationController _animationController;
  Offset _lastTapPosition = Offset.zero;
  bool _isAnimating = false;
  bool _isExternalController = false;
 
  @override
  void initState() {
    super.initState();
    
    _isExternalController = widget.controller != null;
    // Use controller's transformation controller or create new one
    _transformationController = widget.controller?.transformationController ?? TransformationController();

    // Set initial scale
    _transformationController.value = Matrix4.identity()..scale(widget.initialScale);
    
    // Initialize animation controller
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    
    // Set up transformation listener
    _transformationController.addListener(() {
      widget.onTransformationChanged?.call(_transformationController.value);
    });

    // Explicitly call onTransformationChanged with the initial identity matrix
    // as the listener might not be triggered if the initial value is already identity.
    widget.onTransformationChanged?.call(_transformationController.value);
    
    // Connect animation callback if controller exists
    if (widget.controller != null) {
      widget.controller!.animateTo = _animateTo;
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    if (!_isExternalController) {
      _transformationController.dispose();
    }
    super.dispose();
  }

  void _animateTo(Matrix4 targetMatrix) {
    _isAnimating = true;
    final animation = Matrix4Tween(
      begin: _transformationController.value,
      end: targetMatrix,
    ).animate(_animationController);
    
    animation.addListener(() {
      _transformationController.value = animation.value;
    });

    animation.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _isAnimating = false;
      }
    });
    
    _animationController.forward(from: 0);
  }

  void _onDoubleTap() {
    if (!widget.isMobile) return;

    const double targetScale = 2.5;
    final currentMatrix = _transformationController.value;

    if (currentMatrix != Matrix4.identity()) {
      _animateTo(Matrix4.identity());
    } else {
      final x = -_lastTapPosition.dx * (targetScale - 1);
      final y = -_lastTapPosition.dy * (targetScale - 1);
      final targetMatrix = Matrix4.identity()
        ..translate(x, y)
        ..scale(targetScale);
      _animateTo(targetMatrix);
    }
  }

  void _onPointerSignal(PointerSignalEvent pointerSignal) {
    if (widget.isMobile) return;

    if (pointerSignal is PointerScrollEvent) {
      // Do nothing to disable zoom on scroll
    }
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerSignal: _onPointerSignal,
      child: InteractiveViewer(
        transformationController: _transformationController,
        panEnabled: true, // Enable pan for all platforms
        scaleEnabled: widget.isMobile, // Let mobile handle its own pinch-to-zoom
        maxScale: widget.maxScale,
        minScale: widget.minScale,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onDoubleTap: _onDoubleTap,
          onTapDown: (details) => _lastTapPosition = details.localPosition,
          child: widget.child,
        ),
      ),
    );
  }
}