import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_pdf_viewer/src/zoom_view.dart';
import 'package:flutter/gestures.dart';

void main() {
  late Widget testApp;
  List<Matrix4> transformations = [];
  
  void transformationCallback(Matrix4 matrix) {
    transformations.add(matrix);
  }

  setUp(() {
    transformations = [];
    
    testApp = MaterialApp(
      home: Scaffold(
        body: ZoomView(
          minScale: 1.0,
          maxScale: 5.0,
          isMobile: true,
          onTransformationChanged: transformationCallback,
          child: const SizedBox(width: 100, height: 100),
        ),
      ),
    );
  });

  testWidgets('initializes with identity matrix', (tester) async {
    await tester.pumpWidget(testApp);
    await tester.pumpAndSettle();
    expect(transformations.isNotEmpty, isTrue, reason: 'No transformations recorded');
    expect(transformations.first, Matrix4.identity());
  });

  testWidgets('double tap zooms in at tap position', (tester) async {
    await tester.pumpWidget(testApp);
    await tester.pumpAndSettle(); // Wait for initial frame
    
    // First double tap to zoom in
    final zoomView = find.byType(ZoomView);
    await tester.tap(zoomView);
    await tester.pump(kDoubleTapMinTime); // Simulate quick second tap
    await tester.tap(zoomView);
    await tester.pumpAndSettle();
    
    // Verify transformation changed
    expect(transformations.last, isNot(equals(Matrix4.identity())));
  });

  testWidgets('double tap when zoomed resets to identity', (tester) async {
    await tester.pumpWidget(testApp);
    await tester.pumpAndSettle(); // Wait for initial frame
    
    // First double tap to zoom in
    final zoomView = find.byType(ZoomView);
    await tester.tap(zoomView);
    await tester.pump(kDoubleTapMinTime); // Simulate quick second tap
    await tester.tap(zoomView);
    await tester.pumpAndSettle();
    
    // Second double tap to reset
    await tester.tap(zoomView);
    await tester.pump(kDoubleTapMinTime); // Simulate quick second tap
    await tester.tap(zoomView);
    await tester.pumpAndSettle();
    
    // Verify we returned to identity
    expect(transformations.isNotEmpty, isTrue, reason: 'No transformations recorded');
    expect(transformations.last, Matrix4.identity());
  });

  testWidgets('does nothing on double tap when not mobile', (tester) async {
    testApp = MaterialApp(
      home: Scaffold(
        body: ZoomView(
          isMobile: false,
          onTransformationChanged: transformationCallback,
          child: const SizedBox(width: 100, height: 100),
        ),
      ),
    );
    
    await tester.pumpWidget(testApp);
    await tester.pumpAndSettle();
    
    
    final zoomView = find.byType(ZoomView);
    await tester.tap(zoomView);
    await tester.pump(kDoubleTapMinTime); // Simulate quick second tap
    await tester.tap(zoomView);
    await tester.pumpAndSettle();
    
    // Should only have the initial transformation
    expect(transformations, hasLength(1));
    expect(transformations.first, Matrix4.identity());
  });
}