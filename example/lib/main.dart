import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:just_pdf_viewer/just_pdf_viewer.dart';
import 'package:window_manager/window_manager.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';

Future<Map<String, dynamic>> _getWindowState() async {
  try {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/window_state.json');

    if (await file.exists()) {
      final content = await file.readAsString();
      return jsonDecode(content);
    }
  } catch (e) {
    // ignore: avoid_print
    print('Failed to read window state: $e');
  }
  return {};
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize window manager for desktop platforms
  if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
    await windowManager.ensureInitialized();

    // Get window state
    final windowState = await _getWindowState();
    Size? size;
    Offset? position;
    bool isMaximized = false;

    if (windowState.isNotEmpty) {
      size = windowState.containsKey('width') && windowState.containsKey('height')
          ? Size(windowState['width'], windowState['height'])
          : const Size(1024, 768);
      position = windowState.containsKey('x') && windowState.containsKey('y')
          ? Offset(windowState['x'], windowState['y'])
          : null;
      isMaximized = windowState['isMaximized'] ?? false;
    } else {
      size = const Size(1024, 768);
    }

    // Set window options
    WindowOptions windowOptions = WindowOptions(
      size: isMaximized ? null : size,
      center: isMaximized ? false : (position == null),
    );

    await windowManager.waitUntilReadyToShow(windowOptions, () async {
      if (isMaximized) {
        await windowManager.maximize();
      } else if (position != null) {
        await windowManager.setPosition(position);
      }
      await windowManager.show();
      await windowManager.focus();
    });

    // Prevent default window close behavior
    await windowManager.setPreventClose(true);
  }

  runApp(const PdfViewerExampleApp());
}

class PdfViewerExampleApp extends StatefulWidget {
  const PdfViewerExampleApp({super.key});

  @override
  State<PdfViewerExampleApp> createState() => _PdfViewerExampleAppState();
}

class _PdfViewerExampleAppState extends State<PdfViewerExampleApp> {
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

class _PdfViewerExampleState extends State<PdfViewerExample> with WindowListener {
  final JustPdfController _pdfController = JustPdfController();
  int _currentPage = 1;
  int? _totalPages;
  ColorMode _colorMode = ColorMode.day;
  bool _showScrollbar = true;
  Axis _scrollDirection = Axis.vertical;
  double _zoomLevel = 1.0;
  String _pdf = 'assets/sample_big.pdf';

  // Check if the platform is desktop
  bool get isDesktop {
    return !kIsWeb &&
           (Platform.isWindows ||
            Platform.isLinux ||
            Platform.isMacOS);
  }

  @override
  void initState() {
    super.initState();
    if (isDesktop) {
      windowManager.addListener(this);
    }
  }

  @override
  void dispose() {
    if (isDesktop) {
      windowManager.removeListener(this);
    }
    super.dispose();
  }

  Future<void> _saveWindowSize() async {
    final size = await windowManager.getSize();
    final position = await windowManager.getPosition();
    final isMaximized = await windowManager.isMaximized();

    final windowState = {
      'width': size.width,
      'height': size.height,
      'x': position.dx,
      'y': position.dy,
      'isMaximized': isMaximized,
    };

    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/window_state.json');
    await file.writeAsString(jsonEncode(windowState));
    print('Window size saved: ${file.path}');
  }

  @override
  void onWindowClose() async {
    if (isDesktop) {
      // Save window state before closing
      await _saveWindowSize();
      windowManager.destroy();
    }
  }

  @override
  void onWindowFocus() {
    if (isDesktop) {
      // Make sure to call once.
      setState(() {});
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
                    const SizedBox(width: 10),
                    CupertinoSegmentedControl<Axis>(
                      groupValue: _scrollDirection,
                      children: {
                        for (var axis in Axis.values)
                          axis: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8.0),
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
                      setState(() {
                        _zoomLevel = zoom;
                        _pdfController.setZoomLevel(zoom);
                      });
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
                initialPage: 1,
                colorMode: _colorMode,
                showScrollbar: _showScrollbar,
                scrollDirection: _scrollDirection,
                pageSnapping: _scrollDirection == Axis.horizontal,
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
