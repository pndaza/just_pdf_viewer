import 'package:flutter/material.dart';

class PdfController {
  PdfController({required this.initialPage});
  final int initialPage;

  PageController? _pageController;

  void attachController(PageController pageController) {
    _pageController = pageController;
  }

  void gotoPage(int pageNumber) {
    _pageController?.jumpToPage(pageNumber - 1);
  }
}
