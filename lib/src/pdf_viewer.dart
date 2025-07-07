import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'color_mode.dart';
import 'zoom_view.dart';
import 'zoom_controller.dart';
import 'just_pdf_controller.dart';
import 'pdf_page_item.dart';
import 'utils/viewport_utils.dart';

typedef OnPageChanged = void Function(int);

class JustPdfViewer extends StatefulWidget {
  final PdfDocument document; 
  final int initialPage;
  final Axis scrollDirection;
  final JustPdfController? pdfController;
  final OnPageChanged? onPageChanged;
  final ColorMode colorMode;
  final bool showScrollbar;
  final double maxScale;
  final double minScale;
  final Color? scrollbarColor;
  final Widget? loadingWidget;
  final Widget? errorWidget;
  final ZoomController? zoomController;

  const JustPdfViewer({
    super.key,
    required this.document, // Make document required
    this.initialPage = 1,
    this.scrollDirection = Axis.vertical,
    this.pdfController,
    this.onPageChanged,
    this.colorMode = ColorMode.day,
    this.showScrollbar = true,
    this.maxScale = 5.0,
    this.minScale = 1.0,
    this.scrollbarColor,
    this.loadingWidget,
    this.errorWidget,
    this.zoomController,
  });

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
  bool _canScroll = true;
  Timer? _scrollbarHideTimer;
  bool _isScrollbarVisible = false;
  double _currentViewportFraction = 0.8;
  bool _isInitializing = false;

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
    _controller = JustPdfController()..addListener(_handleControllerChange);

    _lastScrollDirection = widget.scrollDirection;
    _lastColorMode = widget.colorMode;

    print('[PDF Viewer] Initializing with page: ${widget.initialPage}');
    _loadDocument();
  }

  void _handleControllerChange() {
    if (mounted) {
      setState(() {});
    }
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

    // The document parameter is now immutable, so we don't need to check for changes here.
    // The user is responsible for providing a new PdfDocument instance if the source changes.
    // If the document instance itself changes, we should reload.
    if (oldWidget.document != widget.document) {
      _loadDocument();
    }
  }

  void _handleScrollDirectionChange() {
    // Store current page before disposing controller
    final currentPage = _controller.currentPage;

    // Dispose old controller
    _pageController?.dispose();
    _pageController = null;
    _lastConstraints = null;

    // Schedule rebuild after frame to ensure proper initialization
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        // Ensure we maintain the current page after scroll direction change
        _controller.gotoPage(currentPage);
        setState(() {});
      }
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
    super.dispose();
  }

  Future<void> _loadDocument() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
      _document = null; // Clear previous document
    });

    try {
      // The PdfDocument from pdfrx is already loaded when passed to the widget.
      // We just need to assign it.
      _document = widget.document;
    } catch (error) {
      _loadError = error;
      // The onLoadError callback is removed as per the plan
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
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

  void _initializePageController(BoxConstraints constraints) {
    if (_document == null || _isInitializing) return;

    _isInitializing = true;

    final width =
        _document!.pages.fold(0.0, (prev, page) => prev + page.width) /
            _document!.pages.length;
    final height =
        _document!.pages.fold(0.0, (prev, page) => prev + page.height) /
            _document!.pages.length;

    double newViewportFraction = ViewportUtils.calculateViewportFraction(
        scrollAxis: widget.scrollDirection,
        parentWidth: constraints.maxWidth,
        parentHeight: constraints.maxHeight,
        pdfWidth: width,
        pdfHeight: height);

    // Store current page before creating new controller
    final currentPage = widget.initialPage;

    // Dispose old controller
    _pageController?.dispose();

    // Create new controller with current page
    print('[PDF Viewer] Initializing PageController with page: $currentPage');
    _pageController = PageController(
        initialPage: (currentPage - 1).clamp(0, _document!.pages.length - 1), // Convert to 0-based and clamp
        viewportFraction: newViewportFraction,
        keepPage: false);

    _currentViewportFraction = newViewportFraction;

    // Attach to internal controller, passing the initial page directly.
    _controller.attachPageController(_pageController!,
        initialPage: currentPage - 1);

    // Initialize external controller if provided
    if (widget.pdfController != null) {
      widget.pdfController!.initialize(_document!,
          initialPage: currentPage,
          pageController: _pageController,
          zoomController: widget.zoomController);
    }

    _isInitializing = false;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final double statusBarHeight = MediaQuery.of(context).padding.top;
    if (widget.scrollDirection == Axis.vertical) {
      _scrollbarTopPadding = statusBarHeight;
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

        // Check if we need to reinitialize the page controller
        bool needsReinit = _pageController == null ||
            _lastConstraints == null ||
            (_lastConstraints!.width - currentSize.width).abs() > 1 ||
            (_lastConstraints!.height - currentSize.height).abs() > 1 ||
            _lastScrollDirection != currentScrollDirection;

        if (needsReinit) {
          _lastConstraints = currentSize;
          _lastScrollDirection = currentScrollDirection;
          _initializePageController(constraints);
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

  Widget _buildPdfView(BuildContext context, PdfDocument document) { // Change type to dynamic
    if (_pageController == null) {
      return const Center(child: CircularProgressIndicator());
    }

    Widget scrollableContent = RepaintBoundary(
      child: ZoomView(
        isMobile: defaultTargetPlatform == TargetPlatform.iOS ||
            defaultTargetPlatform == TargetPlatform.android,
        minScale: widget.minScale,
        maxScale: widget.maxScale,
        controller: widget.zoomController,
        child: PageView.builder(
          controller: _pageController,
          scrollDirection: widget.scrollDirection,
          physics: _canScroll
              ? const ClampingScrollPhysics(parent: PageScrollPhysics())
              : const NeverScrollableScrollPhysics(),
          pageSnapping: widget.scrollDirection == Axis.horizontal,
          onPageChanged: (index) {
            // Update controller state
            print('[PDF Viewer] Page changed to index: $index');
            _controller.onPageChanged(index);
            // Call external callback
            widget.onPageChanged?.call(index + 1);
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
              thumbColor:
                  widget.scrollbarColor ?? Colors.blueGrey.withOpacity(0.8),
              radius: const Radius.circular(10),
              padding: EdgeInsets.only(
                  right: 6, top: _scrollbarTopPadding, bottom: 24),
              timeToFade: const Duration(seconds: 2),
              crossAxisMargin: 4,
              child: scrollableContent,
            ),
    );
  }
}
