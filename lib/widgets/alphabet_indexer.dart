import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AlphabetIndexer extends StatefulWidget {
  final List<String> letters;
  final Set<String> activeLetters;
  final ValueChanged<String> onLetterSelected;
  final VoidCallback? onDragEnd;
  final String? activeLetter;

  const AlphabetIndexer({
    super.key,
    this.letters = const [
      'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J',
      'K', 'L', 'M', 'N', 'O', 'P', 'Q', 'R', 'S', 'T',
      'U', 'V', 'W', 'X', 'Y', 'Z',
    ],
    required this.activeLetters,
    required this.onLetterSelected,
    this.onDragEnd,
    this.activeLetter,
  });

  @override
  State<AlphabetIndexer> createState() => _AlphabetIndexerState();
}

class _AlphabetIndexerState extends State<AlphabetIndexer> {
  String? _lastLetter;

  void _handleTouch(Offset localPosition, double totalHeight) {
    if (totalHeight <= 0 || widget.letters.isEmpty) return;
    final itemHeight = totalHeight / widget.letters.length;
    final index = (localPosition.dy / itemHeight).floor().clamp(0, widget.letters.length - 1);
    final letter = widget.letters[index];
    if (letter != _lastLetter) {
      _lastLetter = letter;
      HapticFeedback.selectionClick();
      widget.onLetterSelected(letter);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final totalHeight = constraints.maxHeight;

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onVerticalDragDown: (details) {
            _handleTouch(details.localPosition, totalHeight);
          },
          onVerticalDragUpdate: (details) {
            _handleTouch(details.localPosition, totalHeight);
          },
          onVerticalDragEnd: (_) {
            _lastLetter = null;
            widget.onDragEnd?.call();
          },
          onVerticalDragCancel: () {
            _lastLetter = null;
            widget.onDragEnd?.call();
          },
          onTapDown: (details) {
            _handleTouch(details.localPosition, totalHeight);
          },
          onTapUp: (_) {
            _lastLetter = null;
            widget.onDragEnd?.call();
          },
          onTapCancel: () {
            _lastLetter = null;
            widget.onDragEnd?.call();
          },
          child: Container(
            width: 24,
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: widget.letters.map((letter) {
                final isActive = widget.activeLetters.contains(letter);
                final isCurrent = widget.activeLetter == letter;

                Color color;
                FontWeight weight;
                if (isCurrent) {
                  color = theme.colorScheme.primary;
                  weight = FontWeight.bold;
                } else if (isActive) {
                  color = theme.colorScheme.onSurface;
                  weight = FontWeight.w600;
                } else {
                  color = theme.colorScheme.onSurface.withValues(alpha: 0.25);
                  weight = FontWeight.normal;
                }

                return Expanded(
                  child: Center(
                    child: Text(
                      letter,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: weight,
                        color: color,
                        height: 1.0,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }
}
