# Just PDF Viewer

A high-performance PDF viewer for Flutter with smooth scrolling, multiple display modes, and robust lifecycle management.
This package is a wrapper over the awesome [pdfrx](https://pub.dev/packages/pdfrx) package.

## Features

- 📚 Multiple PDF sources: Asset, file path, or memory
- 🎨 Customizable color modes: Day, Night, Sepia, Grayscale
- ↔️ Horizontal/vertical scroll directions
- 🔍 Pinch-to-zoom with customizable scale limits
- 🔄 Automatic document reloading on source change
- 📏 Smart viewport calculation for optimal page display
- 🛠 Controller support for programmatic navigation

## Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  just_pdf_viewer: ^0.0.1
```

## Basic Usage

```dart
import 'package:just_pdf_viewer/just_pdf_viewer.dart';

JustPdfViewer(
  assetPath: 'assets/sample.pdf',
  scrollDirection: Axis.vertical,
  colorMode: ColorMode.day,
  pdfController: PdfController(initialPage: 1),
  onPageChanged: (page) => print('Page $page'),
)
```

## Parameters

| Property           | Description                                  | Default       |
|--------------------|----------------------------------------------|---------------|
| `assetPath`        | PDF asset path                               | null          |
| `file`             | PDF File object                              | null          |
| `memory`           | PDF byte data                                | null          |
| `scrollDirection`  | Axis.vertical/horizontal                     | vertical      |
| `colorMode`        | Color scheme (day/night/sepia/grayscale)     | day           |
| `showScrollbar`    | Show/hide scrollbar                          | true          |
| `maxScale`         | Maximum zoom scale                           | 5.0           |
| `minScale`         | Minimum zoom scale                           | 1.0           |
| `scrollbarColor`   | Custom scrollbar color                       | BlueGrey      |
| `loadingWidget`    | Custom loading indicator                     | CircularProgress|
| `errorWidget`      | Custom error display                         | Text widget   |

## Advanced Features

### Programmatic Control

```dart
final controller = PdfController(initialPage: 3);

// Jump to page
controller.jumpToPage(5); 

// Animate to page
controller.animateToPage(
  page: 2,
  duration: Duration(milliseconds: 300),
  curve: Curves.easeInOut,
);
```

### Custom Color Modes

```dart
ColorFiltered(
  colorFilter: ColorFilter.matrix([
    0.33, 0.33, 0.33, 0, 0,
    0.33, 0.33, 0.33, 0, 0,
    0.33, 0.33, 0.33, 0, 0,
    0, 0, 0, 1, 0,
  ]),
  child: JustPdfViewer(...),
)
```

## Lifecycle Management

The viewer automatically:

- Releases PDF resources when app enters background
- Reinitializes when app resumes
- Handles orientation changes
- Maintains scroll position during rebuilds

## Requirements

- Flutter 3.0+
- Dart 2.17+
- iOS 11+/Android API 21+

[//]: # (Add screenshot section here with actual screenshot paths)

## License

MIT License - See [LICENSE](LICENSE) for details.