import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';
import 'zoom_controller.dart';

export 'package:pdfrx/pdfrx.dart' show PdfDocument;

class JustPdfController with ChangeNotifier {
  PdfDocument? _document;
  PageController? _pageController;
  ZoomController? _zoomController;
  int _currentPage = 0;
  int? _pendingPage;
  double _currentScale = 1.0;
  bool _ownsController = false;
  bool _isAttaching = false;

  void initialize(PdfDocument document, {int initialPage = 0, PageController? pageController, ZoomController? zoomController}) {
    _document = document;
    _currentPage = initialPage.clamp(0, document.pages.length - 1);
    if (pageController != null) {
      _pageController = pageController;
      _ownsController = false;
    } else {
      _pageController = PageController(initialPage: _currentPage);
      _ownsController = true;
    }
    
    // Initialize zoom controller
    if (zoomController != null) {
      _zoomController = zoomController;
      _zoomController!.addListener(_onZoomChanged);
    }
    
    notifyListeners();
  }

  void attachPageController(PageController pageController) {
    if (_isAttaching) return; // Prevent recursive calls
    _isAttaching = true;
    
    // Store current page before disposing old controller
    final currentPosition = _currentPage;

    if (_ownsController && _pageController != null) {
      _pageController!.dispose();
    }

    _pageController = pageController;
    _ownsController = false;

    // Schedule navigation to current page after controller is attached
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _isAttaching = false;
      if (_pageController?.hasClients == true) {
        final pageToGo = _pendingPage ?? currentPosition;
        try {
          _pageController!.jumpToPage(pageToGo);
          _pendingPage = null;
        } catch (e) {
          // If jumpToPage fails, store as pending
          _pendingPage = pageToGo;
        }
      } else {
        _pendingPage = currentPosition;
      }
    });
  }

  // Public API
  int get currentPage => _currentPage;
  double get currentScale => _currentScale;
  PageController? get pageController => _pageController;
  ZoomController? get zoomController => _zoomController;
  PdfDocument? get document => _document;

  // Zoom control methods
  void zoomIn({double step = 0.25}) {
    if (_zoomController != null) {
      _zoomController!.zoomIn(step: step);
    }
  }

  void zoomOut({double step = 0.25}) {
    if (_zoomController != null) {
      _zoomController!.zoomOut(step: step);
    }
  }

  void setZoomLevel(double scale) {
    if (_zoomController != null) {
      _zoomController!.setScale(scale);
    }
  }

  void resetZoom() {
    if (_zoomController != null) {
      _zoomController!.reset();
    }
  }

  void fitToWidth() {
    if (_zoomController != null) {
      _zoomController!.fitToWidth();
    }
  }

  void fitToHeight() {
    if (_zoomController != null) {
      _zoomController!.fitToHeight();
    }
  }

  void centerContent() {
    if (_zoomController != null) {
      _zoomController!.centerContent();
    }
  }

  // Internal zoom change handler
  void _onZoomChanged() {
    if (_zoomController != null) {
      final newScale = _zoomController!.currentScale;
      if (_currentScale != newScale) {
        _currentScale = newScale;
        notifyListeners();
      }
    }
  }

  void gotoPage(int page) {
    if (_document == null) return;
    final newPage = page.clamp(0, _document!.pages.length - 1);
    _currentPage = newPage;

    if (_pageController?.hasClients == true && !_isAttaching) {
      try {
        _pageController!.jumpToPage(newPage);
        _pendingPage = null;
      } catch (e) {
        // If navigation fails, store as pending
        _pendingPage = newPage;
      }
    } else {
      _pendingPage = newPage;
    }
    notifyListeners();
  }

  void setScale(double scale) {
    _currentScale = scale;
    notifyListeners();
  }

  // Internal method to handle page changes from PageView
  void onPageChanged(int page) {
    if (_currentPage != page) {
      _currentPage = page;
      _pendingPage = null;
      notifyListeners();
    }
  }

  // Method to retry pending navigation
  void _retryPendingNavigation() {
    if (_pendingPage != null && _pageController?.hasClients == true && !_isAttaching) {
      try {
        _pageController!.jumpToPage(_pendingPage!);
        _pendingPage = null;
      } catch (e) {
        // Keep pending if still fails
      }
    }
  }

  @override
  void dispose() {
    // Remove zoom controller listener
    if (_zoomController != null) {
      _zoomController!.removeListener(_onZoomChanged);
    }
    
    // Only dispose controller if we created it ourselves
    if (_ownsController && _pageController != null) {
      _pageController!.dispose();
    }
    super.dispose();
  }
}