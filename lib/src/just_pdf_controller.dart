import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

export 'package:pdfrx/pdfrx.dart' show PdfDocument;

class JustPdfController with ChangeNotifier {
  PdfDocument? _document;
  PageController? _pageController;
  int _currentPage = 0;
  double _currentScale = 1.0;

  void initialize(PdfDocument document, {int initialPage = 0, PageController? pageController}) {
    _document = document;
    _currentPage = initialPage.clamp(0, document.pages.length - 1);
    if (pageController != null) {
      _pageController = pageController;
    }
    notifyListeners();
  }

  void attachPageController(PageController pageController) {
    _pageController = pageController;
    // Do not call notifyListeners here to avoid setState during build errors.
  }

  // Public API
  int get currentPage => _currentPage;
  double get currentScale => _currentScale;
  PageController? get pageController => _pageController;

  void gotoPage(int page) {
    if (_document == null) return;
    _currentPage = page.clamp(0, _document!.pages.length - 1);
    _pageController?.jumpToPage(_currentPage);
    notifyListeners();
  }

  void setScale(double scale) {
    _currentScale = scale;
    notifyListeners();
  }

  @override
  void dispose() {
    _pageController?.dispose();
    super.dispose();
  }
}