import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'color_mode.dart';
import 'just_pdf_controller.dart';
import 'pdf_page_item.dart';
import 'pdf_source.dart';
import 'zoom_controller.dart';
import 'zoom_view.dart';
import 'utils/viewport_utils.dart';

typedef OnPageChanged = void Function(int);
typedef OnDocumentLoaded = void Function(PdfDocument);
typedef OnDocumentError = void Function(dynamic);

/// Configuration for PDF viewer display options.
@immutable
class PdfViewerConfig {
  final int initialPage;
  final Axis scrollDirection;
  final ColorMode colorMode;
  final bool showScrollbar;
  final double maxScale;
  final double minScale;
  final Color? scrollbarColor;
  final bool pageSnapping;
  const PdfViewerConfig({
    this.initialPage = 1,
    this.scrollDirection = Axis.vertical,
    this.colorMode = ColorMode.day,
    this.showScrollbar = true,
    this.maxScale = 5.0,
    this.minScale = 1.0,
    this.scrollbarColor,
    this.pageSnapping = false,
  });

  /// Creates a copy with modified values.
  PdfViewerConfig copyWith({
    int? initialPage,
    Axis? scrollDirection,
    ColorMode? colorMode,
    bool? showScrollbar,
    double? maxScale,
    double? minScale,
    Color? scrollbarColor,
    bool? pageSnapping,
  }) {
    return PdfViewerConfig(
      initialPage: initialPage ?? this.initialPage,
      scrollDirection: scrollDirection ?? this.scrollDirection,
      colorMode: colorMode ?? this.colorMode,
      showScrollbar: showScrollbar ?? this.showScrollbar,
      maxScale: maxScale ?? this.maxScale,
      minScale: minScale ?? this.minScale,
      scrollbarColor: scrollbarColor ?? this.scrollbarColor,
      pageSnapping: pageSnapping ?? this.pageSnapping,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PdfViewerConfig &&
        other.initialPage == initialPage &&
        other.scrollDirection == scrollDirection &&
        other.colorMode == colorMode &&
        other.showScrollbar == showScrollbar &&
        other.maxScale == maxScale &&
        other.minScale == minScale &&
        other.scrollbarColor == scrollbarColor &&
        other.pageSnapping == pageSnapping;
  }

  @override
  int get hashCode => Object.hash(
        initialPage,
        scrollDirection,
        colorMode,
        showScrollbar,
        maxScale,
        minScale,
        scrollbarColor,
        pageSnapping,
      );
}

/// Configuration for PDF viewer callbacks and controllers.
@immutable
class PdfViewerCallbacks {
  final OnPageChanged? onPageChanged;
  final OnDocumentLoaded? onDocumentLoaded;
  final OnDocumentError? onDocumentError;
  final VoidCallback? onTap;

  const PdfViewerCallbacks({
    this.onPageChanged,
    this.onDocumentLoaded,
    this.onDocumentError,
    this.onTap,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PdfViewerCallbacks &&
        other.onPageChanged == onPageChanged &&
        other.onDocumentLoaded == onDocumentLoaded &&
        other.onDocumentError == onDocumentError &&
        other.onTap == onTap;
  }

  @override
  int get hashCode =>
      Object.hash(onPageChanged, onDocumentLoaded, onDocumentError, onTap);
}

/// Configuration for PDF viewer UI customization.
@immutable
class PdfViewerUI {
  final Widget? loadingWidget;
  final Widget? errorWidget;

  const PdfViewerUI({
    this.loadingWidget,
    this.errorWidget,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PdfViewerUI &&
        other.loadingWidget == loadingWidget &&
        other.errorWidget == errorWidget;
  }

  @override
  int get hashCode => Object.hash(loadingWidget, errorWidget);
}

/// A Flutter widget for displaying PDF documents with various configuration options.
class JustPdfViewer extends StatefulWidget {
  final PdfSource pdfSource;
  final PdfViewerConfig config;
  final PdfViewerCallbacks callbacks;
  final PdfViewerUI ui;
  final JustPdfController? pdfController;
  final ZoomController? zoomController;
  final PdfOpenConfig? pdfOpenConfig;

  const JustPdfViewer({
    super.key,
    required this.pdfSource,
    this.config = const PdfViewerConfig(),
    this.callbacks = const PdfViewerCallbacks(),
    this.ui = const PdfViewerUI(),
    this.pdfController,
    this.zoomController,
    this.pdfOpenConfig,
  });

  /// Creates a PDF viewer from an asset.
  factory JustPdfViewer.asset(
    String name, {
    Key? key,
    PdfViewerConfig config = const PdfViewerConfig(),
    PdfViewerCallbacks callbacks = const PdfViewerCallbacks(),
    PdfViewerUI ui = const PdfViewerUI(),
    JustPdfController? pdfController,
    ZoomController? zoomController,
    PdfOpenConfig? pdfOpenConfig,
  }) =>
      JustPdfViewer(
        key: key,
        pdfSource: AssetSource(name),
        config: config,
        callbacks: callbacks,
        ui: ui,
        pdfController: pdfController,
        zoomController: zoomController,
        pdfOpenConfig: pdfOpenConfig,
      );

  /// Creates a PDF viewer from a file.
  factory JustPdfViewer.file(
    String filePath, {
    Key? key,
    PdfViewerConfig config = const PdfViewerConfig(),
    PdfViewerCallbacks callbacks = const PdfViewerCallbacks(),
    PdfViewerUI ui = const PdfViewerUI(),
    JustPdfController? pdfController,
    ZoomController? zoomController,
    PdfOpenConfig? pdfOpenConfig,
  }) =>
      JustPdfViewer(
        key: key,
        pdfSource: FileSource(filePath),
        config: config,
        callbacks: callbacks,
        ui: ui,
        pdfController: pdfController,
        zoomController: zoomController,
        pdfOpenConfig: pdfOpenConfig,
      );

  /// Creates a PDF viewer from binary data.
  factory JustPdfViewer.data(
    Uint8List data, {
    Key? key,
    PdfViewerConfig config = const PdfViewerConfig(),
    PdfViewerCallbacks callbacks = const PdfViewerCallbacks(),
    PdfViewerUI ui = const PdfViewerUI(),
    JustPdfController? pdfController,
    ZoomController? zoomController,
    PdfOpenConfig? pdfOpenConfig,
  }) =>
      JustPdfViewer(
        key: key,
        pdfSource: DataSource(data),
        config: config,
        callbacks: callbacks,
        ui: ui,
        pdfController: pdfController,
        zoomController: zoomController,
        pdfOpenConfig: pdfOpenConfig,
      );

  /// Creates a PDF viewer from a URI.
  factory JustPdfViewer.uri(
    Uri uri, {
    Key? key,
    PdfViewerConfig config = const PdfViewerConfig(),
    PdfViewerCallbacks callbacks = const PdfViewerCallbacks(),
    PdfViewerUI ui = const PdfViewerUI(),
    JustPdfController? pdfController,
    ZoomController? zoomController,
    PdfOpenConfig? pdfOpenConfig,
    Map<String, String>? headers,
    bool withCredentials = false,
  }) =>
      JustPdfViewer(
        key: key,
        pdfSource:
            UriSource(uri, headers: headers, withCredentials: withCredentials),
        config: config,
        callbacks: callbacks,
        ui: ui,
        pdfController: pdfController,
        zoomController: zoomController,
        pdfOpenConfig: pdfOpenConfig,
      );

  /// Creates a PDF viewer from a URL string.
  factory JustPdfViewer.url(
    String url, {
    Key? key,
    PdfViewerConfig config = const PdfViewerConfig(),
    PdfViewerCallbacks callbacks = const PdfViewerCallbacks(),
    PdfViewerUI ui = const PdfViewerUI(),
    JustPdfController? pdfController,
    ZoomController? zoomController,
    PdfOpenConfig? pdfOpenConfig,
    Map<String, String>? headers,
    bool withCredentials = false,
  }) =>
      JustPdfViewer.uri(
        Uri.parse(url),
        key: key,
        config: config,
        callbacks: callbacks,
        ui: ui,
        pdfController: pdfController,
        zoomController: zoomController,
        pdfOpenConfig: pdfOpenConfig,
        headers: headers,
        withCredentials: withCredentials,
      );

  @override
  State<JustPdfViewer> createState() => _JustPdfViewerState();
}

class _JustPdfViewerState extends State<JustPdfViewer> {
  late final JustPdfController _controller;
  late final ZoomController _zoomController;
  PageController? _pageController;
  PdfDocument? _document;
  dynamic _error;
  bool _loading = true;
  double _viewportFraction = 1.0;

  @override
  void initState() {
    super.initState();
    _controller = widget.pdfController ?? JustPdfController();
    _zoomController = widget.zoomController ?? ZoomController();
    _zoomController.setScaleConstraints(
      minScale: widget.config.minScale,
      maxScale: widget.config.maxScale,
    );
    _loadDocument();
  }

  @override
  void didUpdateWidget(JustPdfViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.pdfSource != oldWidget.pdfSource) {
      _loadDocument();
    }
    if (widget.config != oldWidget.config) {
      _zoomController.setScaleConstraints(
        minScale: widget.config.minScale,
        maxScale: widget.config.maxScale,
      );
    }
    if (widget.pdfController != oldWidget.pdfController) {
      _controller = widget.pdfController ?? JustPdfController();
    }
    if (widget.zoomController != oldWidget.zoomController) {
      _zoomController = widget.zoomController ?? ZoomController();
    }
  }

  @override
  void dispose() {
    if (widget.pdfController == null) {
      _controller.dispose();
    }
    if (widget.zoomController == null) {
      _zoomController.dispose();
    }
    _pageController?.dispose();
    super.dispose();
  }

  Future<void> _loadDocument() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final document = await widget.pdfSource.open(widget.pdfOpenConfig);
      _document = document;
      _pageController?.dispose();
      _pageController =
          PageController(initialPage: widget.config.initialPage - 1);
      _controller.initialize(
        document,
        initialPage: widget.config.initialPage - 1,
        pageController: _pageController,
        zoomController: _zoomController,
      );
      widget.callbacks.onDocumentLoaded?.call(document);
    } catch (e) {
      _error = e;
      widget.callbacks.onDocumentError?.call(e);
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Center(
          child: widget.ui.loadingWidget ?? const CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: widget.ui.errorWidget ??
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error, color: Colors.red, size: 50),
                const SizedBox(height: 8),
                Text('Failed to load PDF: $_error'),
              ],
            ),
      );
    }

    if (_document == null) {
      return const Center(child: Text('No document loaded.'));
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width =
            _document!.pages.fold(0.0, (prev, page) => prev + page.width) /
                _document!.pages.length;
        final height =
            _document!.pages.fold(0.0, (prev, page) => prev + page.height) /
                _document!.pages.length;

        final newViewportFraction = ViewportUtils.calculateViewportFraction(
          scrollAxis: widget.config.scrollDirection,
          parentWidth: constraints.maxWidth,
          parentHeight: constraints.maxHeight,
          pdfWidth: width,
          pdfHeight: height,
        );

        if ((_viewportFraction - newViewportFraction).abs() > 0.001) {
          final currentPage = (_pageController?.hasClients ?? false)
              ? _pageController!.page!.round()
              : _controller.currentPage;
          _pageController?.dispose();
          _pageController = null;
          _pageController = PageController(
            initialPage: currentPage,
            viewportFraction: newViewportFraction,
          );
          _controller.initialize(
            _document!,
            initialPage: currentPage,
            pageController: _pageController,
            zoomController: _zoomController,
          );
          _viewportFraction = newViewportFraction;
          /*
          // Force a rebuild to update the scrollbar with the new controller
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {});
            }
          });
        */
        }
        final pageView = PageView.builder(
          controller: _pageController,
          scrollDirection: widget.config.scrollDirection,
          pageSnapping: widget.config.pageSnapping,
          itemCount: _document!.pages.length,
          itemBuilder: (context, index) {
            return PdfPageItem(
              document: _document!,
              pageNumber: index + 1,
              colorMode: widget.config.colorMode,
            );
          },
          onPageChanged: (page) {
            _controller.onPageChanged(page);
            widget.callbacks.onPageChanged?.call(page + 1);
          },
        );

        final pdfView = ZoomView(
          controller: _zoomController,
          isMobile: defaultTargetPlatform == TargetPlatform.iOS ||
              defaultTargetPlatform == TargetPlatform.android,
          onTap: widget.callbacks.onTap,
          child: pageView,
        );

        if (widget.config.showScrollbar) {
          return ScrollConfiguration(
            behavior: const ScrollBehavior().copyWith(
              scrollbars: false,
            ),
            child: RawScrollbar(
              // create a new one whenever the controller is recreated
              // fixed by gemini pro
              // This UniqueKey() tells Flutter's diffing algorithm that this is a brand new widget,
              // not an update to the old one.
              key: UniqueKey(),
              controller: _pageController,
              thickness: 30,
              minThumbLength: 50,
              thumbColor: widget.config.scrollbarColor ??
                  Colors.blueGrey.withValues(alpha: .8),
              radius: const Radius.circular(10),
              padding: const EdgeInsets.only(right: 6, top: 8, bottom: 16),
              timeToFade: const Duration(seconds: 2),
              crossAxisMargin: 4,
              child: pdfView,
            ),
          );
        }
        return pdfView;
      },
    );
  }
}

/// Extension methods for easier PDF viewer creation.
extension PdfViewerExtensions on PdfSource {
  /// Creates a PDF viewer widget from this source.
  JustPdfViewer toViewer({
    Key? key,
    PdfViewerConfig config = const PdfViewerConfig(),
    PdfViewerCallbacks callbacks = const PdfViewerCallbacks(),
    PdfViewerUI ui = const PdfViewerUI(),
    JustPdfController? pdfController,
    ZoomController? zoomController,
    PdfOpenConfig? pdfOpenConfig,
  }) =>
      JustPdfViewer(
        key: key,
        pdfSource: this,
        config: config,
        callbacks: callbacks,
        ui: ui,
        pdfController: pdfController,
        zoomController: zoomController,
        pdfOpenConfig: pdfOpenConfig,
      );
}

/// Builder class for creating PDF viewers with a fluent API.
class PdfViewerBuilder {
  PdfSource? _pdfSource;
  PdfViewerConfig _config = const PdfViewerConfig();
  PdfViewerCallbacks _callbacks = const PdfViewerCallbacks();
  PdfViewerUI _ui = const PdfViewerUI();
  JustPdfController? _pdfController;
  ZoomController? _zoomController;
  PdfOpenConfig? _pdfOpenConfig;
  Key? _key;

  /// Sets the PDF source.
  PdfViewerBuilder source(PdfSource source) {
    _pdfSource = source;
    return this;
  }

  /// Sets the configuration.
  PdfViewerBuilder config(PdfViewerConfig config) {
    _config = config;
    return this;
  }

  /// Sets the callbacks.
  PdfViewerBuilder callbacks(PdfViewerCallbacks callbacks) {
    _callbacks = callbacks;
    return this;
  }

  /// Sets the UI customization.
  PdfViewerBuilder ui(PdfViewerUI ui) {
    _ui = ui;
    return this;
  }

  /// Sets the PDF controller.
  PdfViewerBuilder controller(JustPdfController controller) {
    _pdfController = controller;
    return this;
  }

  /// Sets the zoom controller.
  PdfViewerBuilder zoomController(ZoomController controller) {
    _zoomController = controller;
    return this;
  }

  /// Sets the PDF open configuration.
  PdfViewerBuilder openConfig(PdfOpenConfig config) {
    _pdfOpenConfig = config;
    return this;
  }

  /// Sets the widget key.
  PdfViewerBuilder key(Key key) {
    _key = key;
    return this;
  }

  /// Builds the PDF viewer widget.
  JustPdfViewer build() {
    if (_pdfSource == null) {
      throw ArgumentError('PDF source must be provided');
    }

    return JustPdfViewer(
      key: _key,
      pdfSource: _pdfSource!,
      config: _config,
      callbacks: _callbacks,
      ui: _ui,
      pdfController: _pdfController,
      zoomController: _zoomController,
      pdfOpenConfig: _pdfOpenConfig,
    );
  }
}
