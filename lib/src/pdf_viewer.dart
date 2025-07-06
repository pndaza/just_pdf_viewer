import 'dart:io';
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'color_mode.dart';
import 'gesture_handler.dart';
import 'just_pdf_controller.dart';
import 'pdf_page_item.dart';
import 'utils/viewport_utils.dart';

typedef OnPageChanged = void Function(int);
typedef OnDocumentLoaded = void Function(PdfDocument document);
typedef OnLoadError = void Function(dynamic error);

class JustPdfViewer extends StatefulWidget {
  final String? assetPath;
  final File? file;
  final Uint8List? memory;
  final Axis scrollDirection;
  final JustPdfController? pdfController;
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
  }) : assert(
            (assetPath != null && file == null && memory == null) ||
                (assetPath == null && file != null && memory == null) ||
                (assetPath == null && file == null && memory != null),
            'Exactly one of assetPath, file, or memory must be provided.');

  @override
  State<JustPdfViewer> createState() => _JustPdfViewerState();
}

class _JustPdfViewerState extends State<JustPdfViewer>
    with WidgetsBindingObserver, AutomaticKeepAliveClientMixin {
  late final JustPdfController _controller;
  PageController? _pageController;
  PdfDocument? _document;
  bool _isLoading = true;
  dynamic _loadError;
  final Set<int> _activePointers = {};
  bool _canScroll = true;
  Timer? _scrollbarHideTimer;
  bool _isScrollbarVisible = false;
  double _currentViewportFraction = 0.8;

  // Cache values to prevent unnecessary rebuilds
  Size? _lastConstraints;
  Axis? _lastScrollDirection;
  ColorMode? _lastColorMode;

  double _scrollbarTopPadding = 0.0;
  final TransformationController _transformationController =
      TransformationController();
  GestureHandler? _gestureHandler;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = JustPdfController()
      ..addListener(_handleControllerChange);
      
    _lastScrollDirection = widget.scrollDirection;
    _lastColorMode = widget.colorMode;
    
    // Initialize gesture handler based on platform
    final isMobile = defaultTargetPlatform == TargetPlatform.iOS ||
                    defaultTargetPlatform == TargetPlatform.android;
    _gestureHandler = GestureHandler(
      isMobile: isMobile,
      transformationController: _transformationController,
    );
    
    _loadDocument();
  }

  void _handleControllerChange() {
    if (mounted) setState(() {});
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
      setState(() {});
    }

    if (needsControllerUpdate) {
      _handleScrollDirectionChange();
    }

    if (oldWidget.assetPath != widget.assetPath ||
        oldWidget.file != widget.file ||
        !listEquals(oldWidget.memory, widget.memory)) {
      _loadDocument();
    }
  }

  void _handleScrollDirectionChange() {
    // Do not access _pageController.page here as the controller may not be attached
    _pageController?.dispose();
    _pageController = null;
    _lastConstraints = null;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _document == null) {
      _loadDocument();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _pageController?.dispose();
    _scrollbarHideTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _transformationController.dispose();
    super.dispose();
  }

  Future<void> _loadDocument() async {
    _transformationController.value = Matrix4.identity();
    
    setState(() {
      _isLoading = true;
      _loadError = null;
      _document = null;
    });

    try {
      final documentFuture = switch ((widget.assetPath, widget.file, widget.memory)) {
        (String path, null, null) => PdfDocument.openAsset(path),
        (null, File file, null) => PdfDocument.openFile(file.path),
        (null, null, Uint8List data) => PdfDocument.openData(data),
        _ => throw ArgumentError('Exactly one source must be provided'),
      };
      _document = await documentFuture;
      widget.onDocumentLoaded?.call(_document!);
    } catch (error) {
      _loadError = error;
      widget.onLoadError?.call(error);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showScrollbar() {
    if (!widget.showScrollbar || !mounted) return;

    _scrollbarHideTimer?.cancel();

    if (mounted) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _isScrollbarVisible = true);
      });
    }
    _scrollbarHideTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _isScrollbarVisible = false);
    });
  }


  @override
  Widget build(BuildContext context) {
    super.build(context);

    final double statusBarHeight = MediaQuery.of(context).padding.top;
    if (widget.scrollDirection == Axis.vertical) {
      _scrollbarTopPadding = statusBarHeight;
    }


    if (_isLoading) {
      return widget.loadingWidget ?? const Center(child: CircularProgressIndicator());
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

          final width = _document!.pages.fold(0.0, (prev, page) => prev + page.width) /
              _document!.pages.length;
          final height = _document!.pages.fold(0.0, (prev, page) => prev + page.height) /
              _document!.pages.length;

          double newViewportFraction = ViewportUtils.calculateViewportFraction(
              scrollAxis: widget.scrollDirection,
              parentWidth: constraints.maxWidth,
              parentHeight: constraints.maxHeight,
              pdfWidth: width,
              pdfHeight: height);

          if (_pageController == null ||
              (_currentViewportFraction - newViewportFraction).abs() > 0.01) {
            _pageController?.dispose();
            _pageController = PageController(
                initialPage: _controller.currentPage,
                viewportFraction: newViewportFraction,
                keepPage: false);
            _currentViewportFraction = newViewportFraction;
            _controller.attachPageController(_pageController!); // Attach the PageController
            
            // Now that we have a new controller, go to the current page
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && _pageController != null && _pageController!.hasClients) {
                _controller.gotoPage(_controller.currentPage);
              }
            });
          }
        }
        // Initialize the external pdfController with the document and internal pageController
        if (widget.pdfController != null && widget.pdfController!.pageController == null) {
          widget.pdfController!.initialize(_document!, initialPage: _controller.currentPage, pageController: _pageController);
        }

        return NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            _showScrollbar();
            return false;
          },
          child: _buildPdfView(context, _document!),
        );
      },
    );
  }

  Widget _buildPdfView(BuildContext context, PdfDocument document) {
    if (_pageController == null) {
      return const Center(child: CircularProgressIndicator());
    }

    Widget scrollableContent = RepaintBoundary(
      child: _gestureHandler!.buildInteractiveViewer(
        child: PageView.builder(
          controller: _pageController,
          scrollDirection: widget.scrollDirection,
          physics: _canScroll
              ? const ClampingScrollPhysics(parent: PageScrollPhysics())
              : const NeverScrollableScrollPhysics(),
          pageSnapping: widget.scrollDirection == Axis.horizontal,
          onPageChanged: (index) {
            // Only update if the page actually changed
            if (index != _controller.currentPage) {
              _controller.gotoPage(index);
              widget.onPageChanged?.call(index + 1);
            }
          },
          itemCount: document.pages.length,
          itemBuilder: (context, index) {
            return PdfPageItem(
              document: document,
              pageNumber: index + 1,
              colorMode: widget.colorMode,
            );
          },
        ),
      ),
    );

    return ScrollConfiguration(
      behavior: const ScrollBehavior().copyWith(
        scrollbars: false,
        overscroll: true,
        physics: const BouncingScrollPhysics(),
      ),
      child: !widget.showScrollbar
          ? scrollableContent
          : RawScrollbar(
              controller: _pageController,
              thickness: 30,
              minThumbLength: 50,
              thumbColor: widget.scrollbarColor ?? Colors.blueGrey.withOpacity(0.8),
              radius: const Radius.circular(10),
              padding: EdgeInsets.only(right: 6, top: _scrollbarTopPadding, bottom: 24),
              timeToFade: const Duration(seconds: 2),
              crossAxisMargin: 4,
              child: scrollableContent),
    );
  }


}
