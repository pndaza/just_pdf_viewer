import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:just_pdf_viewer/just_pdf_viewer.dart';

void main() => runApp(const PdfViewerExampleApp());

class PdfViewerExampleApp extends StatelessWidget {
  const PdfViewerExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PDF Viewer Example',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const PdfViewerExample(),
    );
  }
}

class PdfViewerExample extends StatefulWidget {
  const PdfViewerExample({super.key});

  @override
  State<PdfViewerExample> createState() => _PdfViewerExampleState();
}

class _PdfViewerExampleState extends State<PdfViewerExample> {
  final JustPdfController _pdfController = JustPdfController();
  int _currentPage = 1;
  int? _totalPages;
  ColorMode _colorMode = ColorMode.day;
  bool _showScrollbar = true;
  Axis _scrollDirection = Axis.vertical;
  double _zoomLevel = 1.0; // Initial zoom level
  String _pdf = 'assets/sample_big.pdf';

  void _setZoomLevel(double newZoomLevel) {
    setState(() {
      _zoomLevel = newZoomLevel.clamp(
          0.5, 3.0); // Clamp zoom level between 0.5x and 3.0x
    });
    _pdfController.setScale(_zoomLevel); // Update scale using controller
  }

  void _goToPage(int page) {
    if (page >= 1 && page <= (_totalPages ?? 1)) {
      if (_pdfController.pageController != null) {
        _pdfController.gotoPage(page);
      }
      setState(() => _currentPage = page);
    }
  }

  void _handlePageChanged(int page) {
    setState(() => _currentPage = page);
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Advanced PDF Viewer Example'),
      ),
      body: Column(
        children: [
          // Controls
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.navigate_before),
                      onPressed: () => _goToPage(_currentPage - 1),
                    ),
                    Text('Page $_currentPage/${_totalPages ?? '?'}'),
                    IconButton(
                      icon: const Icon(Icons.navigate_next),
                      onPressed: () => _goToPage(_currentPage + 1),
                    ),
                    SizedBox(width: 10),
                    CupertinoSegmentedControl<Axis>(
                      groupValue: _scrollDirection,
                      children: {
                        for (var axis in Axis.values)
                          axis: Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 8.0),
                            child: Text(axis.toString().split('.').last),
                          ),
                      },
                      onValueChanged: (Axis? axis) {
                        if (axis != null) {
                          setState(() => _scrollDirection = axis);
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                CupertinoSegmentedControl<ColorMode>(
                  groupValue: _colorMode,
                  children: {
                    for (var mode in ColorMode.values)
                      mode: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: Text(mode.toString().split('.').last),
                      ),
                  },
                  onValueChanged: (ColorMode? mode) {
                    if (mode != null) {
                      setState(() => _colorMode = mode);
                    }
                  },
                ),
                const SizedBox(height: 10),
                CupertinoSegmentedControl<double>(
                  groupValue: _zoomLevel,
                  children: {
                    0.5: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8.0),
                      child: Text('50%'),
                    ),
                    1.0: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8.0),
                      child: Text('100%'),
                    ),
                    1.5: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8.0),
                      child: Text('150%'),
                    ),
                    2.0: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8.0),
                      child: Text('200%'),
                    ),
                    3.0: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8.0),
                      child: Text('300%'),
                    ),
                  },
                  onValueChanged: (double? zoom) {
                    if (zoom != null) {
                      _setZoomLevel(zoom);
                    }
                  },
                ),
                const SizedBox(height: 10),
                CupertinoSegmentedControl<String>(
                  groupValue: _pdf,
                  children: {
                    'assets/sample.pdf': const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8.0),
                      child: Text('small pdf'),
                    ),
                    'assets/sample_big.pdf': const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8.0),
                      child: Text('big pdf'),
                    ),
                  },
                  onValueChanged: (String? pdf) {
                    if (pdf != null) {
                      _pdf = pdf;
                      setState(() {
                        _pdf = pdf;
                      });
                    }
                  },
                ),
              ],
            ),
          ),

          // PDF Viewer
          Expanded(
            child: JustPdfViewer.asset(
              _pdf,
              pdfController: _pdfController,
              config: PdfViewerConfig(
                initialPage: 877,
                colorMode: _colorMode,
                showScrollbar: _showScrollbar,
                scrollDirection: _scrollDirection,
              ),
              callbacks: PdfViewerCallbacks(
                onPageChanged: _handlePageChanged,
                onDocumentLoaded: (document) {
                  setState(() {
                    _totalPages = document.pages.length;
                  });
                },
                onDocumentError: (error) {
                  // Handle error
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
