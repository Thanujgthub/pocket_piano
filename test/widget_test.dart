import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_piano/main.dart';

void main() {
  testWidgets('Pocket Piano app loads and displays UI components', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const PocketPianoApp());
    await tester.pumpAndSettle();

    // Verify main title and subtitle
    expect(find.text('Pocket Piano'), findsOneWidget);
    expect(find.text('A pocket-sized piano for every screen'), findsOneWidget);

    // Verify Piano Keyboard section
    expect(find.text('Piano Keyboard'), findsOneWidget);
    expect(find.text('24 keys'), findsOneWidget);

    // Verify Hero Display note status
    expect(find.text('Ready to play'), findsOneWidget);

    // Verify Controls section
    expect(find.text('Controls'), findsOneWidget);
    expect(find.text('Octave'), findsOneWidget);
    expect(find.text('Timbre'), findsOneWidget);
    expect(find.text('Sustain'), findsOneWidget);

    // Verify Recent Notes section
    expect(find.text('Recent Notes'), findsOneWidget);
    expect(find.text('Your played notes will appear here.'), findsOneWidget);
  });

  testWidgets('Octave increment and decrement buttons update octave text', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const PocketPianoApp());
    await tester.pumpAndSettle();

    // Default octave is 4
    expect(find.text('4'), findsWidgets);

    // Find increment octave button (+)
    final addIcon = find.byIcon(Icons.add_rounded);
    expect(addIcon, findsOneWidget);

    // Ensure visible and tap + to increase octave
    await tester.ensureVisible(addIcon);
    await tester.tap(addIcon);
    await tester.pump();

    // Octave should change to 5
    expect(find.text('5'), findsWidgets);
  });
}
