import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';
import 'color_mode.dart';

class PdfPageItem extends StatelessWidget {
  const PdfPageItem({
    super.key,
    required this.document,
    required this.pageNumber,
    required this.colorMode,
  });

  final PdfDocument document;
  final int pageNumber;
  final ColorMode colorMode;

  @override
  Widget build(BuildContext context) {
    return ColorFiltered(
      colorFilter: ColorFilter.matrix(predefinedFilters[colorMode]!),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 2),
        child: PdfPageView(
          document: document,
          pageNumber: pageNumber,
        ),
      ),
    );
  }
}