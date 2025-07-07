import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:just_pdf_viewer/just_pdf_viewer.dart';
import 'package:http/http.dart' as http;

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
  bool _isLoading = true;
  String? _errorMessage;
  Uint8List? _pdfBytes;
  ColorMode _colorMode = ColorMode.day;
  bool _showScrollbar = true;
  Axis _scrollDirection = Axis.vertical;
  double _zoomLevel = 1.0; // Initial zoom level
  String _pdf = 'assets/sample.pdf';

  void _setZoomLevel(double newZoomLevel) {
    setState(() {
      _zoomLevel = newZoomLevel.clamp(
          0.5, 3.0); // Clamp zoom level between 0.5x and 3.0x
    });
    _pdfController.setScale(_zoomLevel); // Update scale using controller
  }

  Future<void> _loadPdfFromNetwork() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final response = await http.get(Uri.parse(
          'https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf'));

      if (response.statusCode == 200) {
        setState(() {
          _pdfBytes = response.bodyBytes;
          _isLoading = false;
        });
      } else {
        throw Exception('Failed to load PDF: ${response.statusCode}');
      }
    } catch (e) {
      setState(() => _errorMessage = 'Failed to load PDF: $e');
      setState(() => _isLoading = false);
    }
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

  Future<Uint8List?> _loadPdfData(String assetPath) async {
    final byteData = await rootBundle.load(assetPath);
    return byteData.buffer.asUint8List(
      byteData.offsetInBytes,
      byteData.lengthInBytes,
    );
  }

  @override
  void initState() {
    super.initState();
    // _loadPdfFromNetwork();
    final startTime = DateTime.now();
    _loadPdfData('assets/sample_big.pdf').then((data) {
      final endTime = DateTime.now();
      final loadingTime = endTime.difference(startTime);
      setState(() {
        _pdfBytes = data;
        _isLoading = false;
      });
      print('PDF loaded in $loadingTime');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Advanced PDF Viewer Example'),
        actions: [
          IconButton(
            icon: const Icon(Icons.cloud_download),
            onPressed: _loadPdfFromNetwork,
            tooltip: 'Load PDF from Network',
          ),
        ],
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
                  onValueChanged: (String? pdf) async {
                    if (pdf != null) {
                      _pdf = pdf;
                      final startTime = DateTime.now();
                      _loadPdfData(pdf).then((data) {
                        final endTime = DateTime.now();
                        final loadingTime = endTime.difference(startTime);
                        setState(() {
                          _pdfBytes = data;
                          _isLoading = false;
                        });
                        print('aseet tp memory loaded in ms ${loadingTime.inMilliseconds}');
                        PdfDocument.openData(data!).then((document) {
                          final endTime = DateTime.now();
                          print(
                              'pdf document loaded in ms ${endTime.difference(startTime).inMilliseconds}');
                        });
                      });
                    }
                  },
                ),
              ],
            ),
          ),

          // PDF Viewer
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                    ? Center(child: Text(_errorMessage!))
                    : JustPdfViewer(
                        // assetPath: 'assets/sample_big.pdf',
                        memory: _pdfBytes,
                        pdfController: _pdfController,
                        // The initialPage is now set within the JustPdfController's initialize method
                        // which is called by JustPdfViewer.
                        onPageChanged: _handlePageChanged,
                        colorMode: _colorMode,
                        showScrollbar: _showScrollbar,
                        scrollDirection: _scrollDirection,
                        // zoomLevel: _zoomLevel, // Pass the zoom level
                        onDocumentLoaded: (document) =>
                            setState(() => _totalPages = document.pages.length),
                      ),
          ),
        ],
      ),
    );
  }
}
