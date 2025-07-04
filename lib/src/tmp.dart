import 'dart:io';
import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';
import 'color_mode.dart';
import 'pdf_controller.dart';

typedef OnPageChanged = void Function(int);
typedef OnDocumentLoaded = void Function(PdfDocument document);
typedef OnLoadError = void Function(dynamic error);

class JustPdfViewer extends StatefulWidget {
  final String? assetPath;
  final File? file;
  final Axis scrollDirection;
  final PdfController? pdfController;
  final OnPageChanged? onPageChanged;
  final OnDocumentLoaded? onDocumentLoaded;
  final OnLoadError? onLoadError;
  final ColorMode colorMode;
  final bool showScrollbar;
  final double maxScale;
  final double minScale;
  final Color? scrollbarColor;
  final Widget? loadingWidget;
  final Widget? errorWidget;

  const JustPdfViewer({
    super.key,
    this.assetPath,
    this.file,
    this.scrollDirection = Axis.vertical,
    this.pdfController,
    this.onPageChanged,
    this.onDocumentLoaded,
    this.onLoadError,
    this.colorMode = ColorMode.day,
    this.showScrollbar = true,
    this.maxScale = 5.0,
    this.minScale = 1.0,
    this.scrollbarColor,
    this.loadingWidget,
    this.errorWidget,
  }) : assert((assetPath != null) ^ (file != null),
            'Either assetPath or file must be provided, but not both');

  @override
  State<JustPdfViewer> createState() => _JustPdfViewerState();
}

class _JustPdfViewerState extends State<JustPdfViewer>
    with WidgetsBindingObserver {
  PageController? _pageController;
  final Set<int> _activePointers = {};
  bool _canScroll = true;
  PdfDocument? _document;
  bool _isLoading = true;
  dynamic _loadError;
  double _currentScale = 1.0;
  Timer? _scrollbarHideTimer;
  bool _isScrollbarVisible = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadDocument();
  }

  @override
  void didUpdateWidget(JustPdfViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.assetPath != widget.assetPath ||
        oldWidget.file != widget.file) {
      _loadDocument();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Handle app lifecycle changes to properly manage PDF document resources
    if (state == AppLifecycleState.resumed && _document == null) {
      _loadDocument();
    } else if (state == AppLifecycleState.paused) {
      // Consider closing document to free resources when app is in background
      // But only if not actively viewing
    }
  }

  @override
  void dispose() {
    _pageController?.dispose();
    _scrollbarHideTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    // Properly close the document to free resources
    // _document?.close();
    super.dispose();
  }

  Future<void> _loadDocument() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _loadError = null;
      });
    }

    try {
      final document = await _openPdf();
      if (mounted) {
        setState(() {
          _document = document;
          _isLoading = false;
        });
        widget.onDocumentLoaded?.call(document);
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _loadError = error;
          _isLoading = false;
        });
        widget.onLoadError?.call(error);
      }
    }
  }

  void _showScrollbar() {
    if (!widget.showScrollbar) return;

    _scrollbarHideTimer?.cancel();
    setState(() {
      _isScrollbarVisible = true;
    });

    _scrollbarHideTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _isScrollbarVisible = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final initialPage = widget.pdfController?.initialPage ?? 1;

    if (_isLoading) {
      return widget.loadingWidget ??
          const Center(child: CircularProgressIndicator());
    }

    if (_loadError != null) {
      return widget.errorWidget ??
          Center(child: Text('Failed to load PDF: ${_loadError.toString()}'));
    }

    if (_document == null) {
      return const Center(child: Text('No document loaded'));
    }

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final parentWidth = constraints.maxWidth;
        final parentHeight = constraints.maxHeight;

        final width =
            _document!.pages.fold(0.0, (prev, page) => prev + page.width) /
                _document!.pages.length;
        final height =
            _document!.pages.fold(0.0, (prev, page) => prev + page.height) /
                _document!.pages.length;

        double viewportFraction = _calculateViewportFraction(
            scrollAxis: widget.scrollDirection,
            parentWidth: parentWidth,
            parentHeight: parentHeight,
            pdfWidth: width,
            pdfHeight: height);

        _pageController ??= PageController(
            initialPage: initialPage - 1, viewportFraction: viewportFraction);

        widget.pdfController?.attachController(_pageController!);

        return NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            _showScrollbar();
            return false;
          },
          child: _buildPdfView(context, _document!, initialPage),
        );
      },
    );
  }

  Widget _buildPdfView(
    BuildContext context,
    PdfDocument document,
    int initialPage,
  ) {
    final bool isIOS = defaultTargetPlatform == TargetPlatform.iOS;
    final bool isAndroid = defaultTargetPlatform == TargetPlatform.android;
    final bool isMobile = isIOS || isAndroid;

    // Enhanced gesture handling for better zoom and pan experience
    Widget scrollableContent = Listener(
      onPointerDown: (event) {
        _activePointers.add(event.pointer);
        if (_activePointers.length >= 2) {
          setState(() {
            _canScroll = false;
          });
        }
        _showScrollbar();
      },
      onPointerUp: (event) {
        _activePointers.remove(event.pointer);
        if (_activePointers.length < 2) {
          setState(() {
            _canScroll = true;
          });
        }
      },
      onPointerCancel: (event) {
        _activePointers.remove(event.pointer);
        if (_activePointers.length < 2) {
          setState(() {
            _canScroll = true;
          });
        }
      },
      child: GestureDetector(
        onDoubleTap: isMobile
            ? () {
                // Toggle between default scale and zoomed in
                setState(() {
                  _currentScale =
                      _currentScale > widget.minScale ? widget.minScale : 2.5;
                });
              }
            : null,
        child: InteractiveViewer(
          maxScale: widget.maxScale,
          minScale: widget.minScale,
          onInteractionUpdate: (details) {
            if (details.scale != 1.0) {
              setState(() {
                _currentScale = (_currentScale * details.scale)
                    .clamp(widget.minScale, widget.maxScale);
              });
            }
            _showScrollbar();
          },
          child: PageView.builder(
            controller: _pageController,
            scrollDirection: widget.scrollDirection,
            physics: _canScroll
                ? const ClampingScrollPhysics(parent: PageScrollPhysics())
                : const NeverScrollableScrollPhysics(),
            pageSnapping: widget.scrollDirection == Axis.horizontal &&
                _currentScale <= 1.2,
            onPageChanged: widget.onPageChanged == null
                ? null
                : (index) => widget.onPageChanged?.call(index + 1),
            itemCount: document.pages.length,
            itemBuilder: (context, index) {
              return Container(
                alignment: Alignment.center,
                padding: const EdgeInsets.only(bottom: 2),
                color: _getBackGroundColor(widget.colorMode),
                child: ColorFiltered(
                  colorFilter:
                      ColorFilter.matrix(predefinedFilters[widget.colorMode]!),
                  child: PdfPageView(
                    document: document,
                    pageNumber: index + 1,
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );

    // Improved scrollbar behavior with platform-specific differences
    return ScrollConfiguration(
      behavior: const ScrollBehavior().copyWith(
        scrollbars: false,
        overscroll: isMobile,
        physics: isMobile
            ? const BouncingScrollPhysics()
            : const ClampingScrollPhysics(),
      ),
      child: !widget.showScrollbar
          ? scrollableContent
          : isIOS
              ? CupertinoScrollbar(
                  controller: _pageController,
                  thickness: _isScrollbarVisible ? 20 : 10,
                  thicknessWhileDragging: 20,
                  radius: const Radius.circular(10),
                  radiusWhileDragging: const Radius.circular(10),
                  thumbVisibility: _isScrollbarVisible,
                  child: scrollableContent,
                )
              : ScrollbarTheme(
                  data: ScrollbarThemeData(
                    interactive: true,
                    trackVisibility:
                        WidgetStateProperty.all(_isScrollbarVisible),
                    thumbVisibility:
                        WidgetStateProperty.all(_isScrollbarVisible),
                    thickness: WidgetStateProperty.resolveWith<double>(
                      (states) {
                        if (states.contains(WidgetState.dragged) ||
                            states.contains(WidgetState.hovered)) {
                          return 20;
                        }
                        return 10;
                      },
                    ),
                    thumbColor: WidgetStateProperty.all(widget.scrollbarColor ??
                        Colors.blueGrey.withOpacity(0.8)),
                    radius: const Radius.circular(10),
                    minThumbLength: 40,
                    crossAxisMargin: 4,
                  ),
                  child: Scrollbar(
                    controller: _pageController,
                    thickness: _isScrollbarVisible ? 12 : 6,
                    child: scrollableContent,
                  ),
                ),
    );
  }

  Future<PdfDocument> _openPdf() async {
    if (widget.assetPath != null) {
      return PdfDocument.openAsset(widget.assetPath!);
    } else if (widget.file != null) {
      return PdfDocument.openFile(widget.file!.path);
    } else {
      throw Exception('Either assetPath or file must be provided');
    }
  }

  double _calculateViewportFraction({
    required Axis scrollAxis,
    required double parentWidth,
    required double parentHeight,
    required double pdfWidth,
    required double pdfHeight,
  }) {
    if (scrollAxis == Axis.horizontal) {
      return 1.0;
    }

    final screenAspectRatio = parentHeight / parentWidth;
    final pdfAspectRatio = pdfHeight / pdfWidth;
    return pdfAspectRatio / screenAspectRatio;
  }

  Color _getBackGroundColor(ColorMode colorMode) {
    switch (colorMode) {
      case ColorMode.day:
        return Colors.grey.shade200;
      case ColorMode.night:
        return Colors.grey.shade800;
      case ColorMode.sepia:
        return const Color.fromARGB(220, 255, 255, 213);
      case ColorMode.grayscale:
        return Colors.grey.shade300;
    }
  }
}
