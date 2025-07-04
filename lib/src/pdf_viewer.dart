import 'dart:io';
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:pdfrx/pdfrx.dart';
import 'color_mode.dart';
import 'pdf_controller.dart';

typedef OnPageChanged = void Function(int);
typedef OnDocumentLoaded = void Function(PdfDocument document);
typedef OnLoadError = void Function(dynamic error);

class JustPdfViewer extends StatefulWidget {
  final String? assetPath;
  final File? file;
  final Uint8List? memory;
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
    this.memory,
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
  }) : assert((assetPath != null) ^ (file != null) ^ (memory != null),
            'Either assetPath or file must be provided, but not both');

  @override
  State<JustPdfViewer> createState() => _JustPdfViewerState();
}

class _JustPdfViewerState extends State<JustPdfViewer>
    with WidgetsBindingObserver, AutomaticKeepAliveClientMixin {
  PageController? _pageController;
  final Set<int> _activePointers = {};
  bool _canScroll = true;
  PdfDocument? _document;
  bool _isLoading = true;
  dynamic _loadError;
  double _currentScale = 1.0;
  Timer? _scrollbarHideTimer;
  bool _isScrollbarVisible = false;
  int _currentPageIndex = 0;
  double _currentViewportFraction = 0.8;

  // Cache values to prevent unnecessary rebuilds
  Size? _lastConstraints;
  Axis? _lastScrollDirection;
  ColorMode? _lastColorMode;

  double _scrollbarTopPadding = 0.0;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _currentPageIndex = (widget.pdfController?.initialPage ?? 1) - 1;
    _lastScrollDirection = widget.scrollDirection;
    _lastColorMode = widget.colorMode;
    _loadDocument();
  }

  @override
  void didUpdateWidget(JustPdfViewer oldWidget) {
    super.didUpdateWidget(oldWidget);

    bool needsControllerUpdate = false;

    if (oldWidget.scrollDirection != widget.scrollDirection) {
      _lastScrollDirection = widget.scrollDirection;
      needsControllerUpdate = true;
    }

    if (oldWidget.colorMode != widget.colorMode) {
      _lastColorMode = widget.colorMode;
      // Color mode change doesn't need controller update, just rebuild
      setState(() {});
    }

    if (needsControllerUpdate) {
      _handleScrollDirectionChange();
    }

    if (oldWidget.assetPath != widget.assetPath ||
        oldWidget.file != widget.file) {
      _loadDocument();
    }
  }

  void _handleScrollDirectionChange() {
    // Preserve current page when scroll direction changes
    if (_pageController != null && _pageController!.hasClients) {
      _currentPageIndex = _pageController!.page?.round() ?? _currentPageIndex;
    }

    // Dispose old controller and create new one with preserved page
    _pageController?.dispose();
    _pageController = null;
    _lastConstraints = null; // Force recalculation of viewport fraction

    // Trigger rebuild to create new controller with correct viewport fraction
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Handle app lifecycle changes to properly manage PDF document resources
    if (state == AppLifecycleState.resumed && _document == null) {
      _loadDocument();
    }
  }

  @override
  void dispose() {
    _pageController?.dispose();
    _pageController = null;
    _scrollbarHideTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
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
          // Reset current page index to ensure it's within valid range
          _currentPageIndex =
              _currentPageIndex.clamp(0, document.pages.length - 1);
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
    if (!widget.showScrollbar || !mounted) return;

    _scrollbarHideTimer?.cancel();

    if (mounted) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _isScrollbarVisible = true);
      });
    }
    _scrollbarHideTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() => _isScrollbarVisible = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final initialPage = widget.pdfController?.initialPage ?? 1;
    final double statusBarHeight = MediaQuery.of(context).padding.top;
    if (widget.scrollDirection == Axis.vertical) {
      _scrollbarTopPadding = statusBarHeight;
      // print('statusBarHeight: $statusBarHeight');
    }

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
        final currentSize = Size(constraints.maxWidth, constraints.maxHeight);
        final currentScrollDirection = widget.scrollDirection;

        if (_lastConstraints == null ||
            (_lastConstraints!.width - currentSize.width).abs() > 1 ||
            (_lastConstraints!.height - currentSize.height).abs() > 1 ||
            _lastScrollDirection != currentScrollDirection) {
          _lastConstraints = currentSize;
          _lastScrollDirection = currentScrollDirection;

          // final parentWidth = constraints.maxWidth;
          // final parentHeight = constraints.maxHeight;

          final width =
              _document!.pages.fold(0.0, (prev, page) => prev + page.width) /
                  _document!.pages.length;
          final height =
              _document!.pages.fold(0.0, (prev, page) => prev + page.height) /
                  _document!.pages.length;

          double newViewportFraction = _calculateViewportFraction(
              scrollAxis: widget.scrollDirection,
              parentWidth: constraints.maxWidth,
              parentHeight: constraints.maxHeight,
              pdfWidth: width,
              pdfHeight: height);

          if (_pageController == null ||
              (_currentViewportFraction - newViewportFraction).abs() > 0.01) {
            // Preserve current page if controller exists
            if (_pageController != null && _pageController!.hasClients) {
              _currentPageIndex =
                  _pageController!.page?.round() ?? _currentPageIndex;
            }

            _pageController?.dispose();
            _pageController = PageController(
                initialPage: _currentPageIndex,
                viewportFraction: newViewportFraction,
                keepPage: false);
            _currentViewportFraction = newViewportFraction;
          }
        }
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
    if (_pageController == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final bool isIOS = defaultTargetPlatform == TargetPlatform.iOS;
    final bool isAndroid = defaultTargetPlatform == TargetPlatform.android;
    final bool isMobile = isIOS || isAndroid;

    // Enhanced gesture handling for better zoom and pan experience
    Widget scrollableContent = RepaintBoundary(
      child: Listener(
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
              onPageChanged: (index) {
                _currentPageIndex = index;
                widget.onPageChanged?.call(index + 1);
              },
              itemCount: document.pages.length,
              itemBuilder: (context, index) {
                return _PdfPageItem(
                  document: document,
                  pageNumber: index + 1,
                  colorMode: widget.colorMode,
                );
              },
            ),
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
          : RawScrollbar(
              controller: _pageController,
              thickness: 30,
              minThumbLength: 50,
              thumbColor: widget.scrollbarColor ??
                  Colors.blueGrey.withValues(alpha: .8),
              radius: const Radius.circular(10),
              padding: EdgeInsets.only(
                  right: 6, top: _scrollbarTopPadding, bottom: 24),
              timeToFade: const Duration(seconds: 2),
              crossAxisMargin: 4,
              child: scrollableContent),
    );
  }

  Future<PdfDocument> _openPdf() async {
    if (widget.assetPath != null) {
      return PdfDocument.openAsset(widget.assetPath!);
    } else if (widget.file != null) {
      return PdfDocument.openFile(widget.file!.path);
    } else if (widget.memory != null) {
      return PdfDocument.openData(widget.memory!);
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
}

class _PdfPageItem extends StatelessWidget {
  const _PdfPageItem({
    required this.document,
    required this.pageNumber,
    required this.colorMode,
  });

  final PdfDocument document;
  final int pageNumber;
  final ColorMode colorMode;

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.only(bottom: 2),
      color: _getBackGroundColor(colorMode),
      child: ColorFiltered(
        colorFilter: ColorFilter.matrix(predefinedFilters[colorMode]!),
        child: PdfPageView(
          document: document,
          pageNumber: pageNumber,
        ),
      ),
    );
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
