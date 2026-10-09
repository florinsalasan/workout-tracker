import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_tracker/widgets/alphabet_indexer.dart';

void main() {
  testWidgets('AlphabetIndexer renders letters and calls onLetterSelected on tap',
      (WidgetTester tester) async {
    String? selectedLetter;
    bool dragEnded = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 600,
            width: 30,
            child: AlphabetIndexer(
              activeLetters: const {'A', 'B', 'C'},
              activeLetter: 'A',
              onLetterSelected: (letter) {
                selectedLetter = letter;
              },
              onDragEnd: () {
                dragEnded = true;
              },
            ),
          ),
        ),
      ),
    );

    expect(find.text('A'), findsOneWidget);
    expect(find.text('Z'), findsOneWidget);

    // Tap on letter 'A'
    await tester.tap(find.text('A'));
    await tester.pump();

    expect(selectedLetter, 'A');
    expect(dragEnded, isTrue);
  });
}
