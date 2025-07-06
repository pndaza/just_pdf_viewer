import 'package:flutter/material.dart';

class ViewportUtils {
  static double calculateViewportFraction({
    required Axis scrollAxis,
    required double parentWidth,
    required double parentHeight,
    required double pdfWidth,
    required double pdfHeight,
  }) {
    if (scrollAxis == Axis.horizontal) return 1.0;
    final screenAspectRatio = parentHeight / parentWidth;
    final pdfAspectRatio = pdfHeight / pdfWidth;
    return pdfAspectRatio / screenAspectRatio;
  }
}