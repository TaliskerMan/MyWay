import 'package:flutter/material.dart';

/// A full-screen transparent modal overlay enabling users to select a desktop
/// recording area box via drag and pan gestures.
class AreaSelector extends StatefulWidget {
  /// Creates a new [AreaSelector] overlay page.
  const AreaSelector({super.key});

  @override
  State<AreaSelector> createState() => _AreaSelectorState();
}

class _AreaSelectorState extends State<AreaSelector> {
  Offset? _startPoint;
  Offset? _currentPoint;

  Rect? get _selectionRect {
    if (_startPoint == null || _currentPoint == null) return null;
    return Rect.fromPoints(_startPoint!, _currentPoint!);
  }

  @override
  Widget build(BuildContext context) {
    final rect = _selectionRect;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Fullscreen gesture detector and painter
          GestureDetector(
            onPanStart: (details) {
              setState(() {
                _startPoint = details.localPosition;
                _currentPoint = details.localPosition;
              });
            },
            onPanUpdate: (details) {
              setState(() {
                _currentPoint = details.localPosition;
              });
            },
            child: CustomPaint(
              size: Size.infinite,
              painter: CutoutPainter(rect),
            ),
          ),
          // Help text overlay at the top
          Positioned(
            top: 40,
            left: 20,
            right: 20,
            child: IgnorePointer(
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.teal.withValues(alpha: 0.5),
                    ),
                  ),
                  child: const Text(
                    'Click and drag to select a recording area',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Action buttons at the bottom (only show if a valid area is drawn)
          if (rect != null && rect.width > 20 && rect.height > 20)
            Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey.shade900,
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.grey),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                      ),
                      onPressed: () {
                        setState(() {
                          _startPoint = null;
                          _currentPoint = null;
                        });
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text('Reset'),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 14,
                        ),
                      ),
                      onPressed: () {
                        Navigator.of(context).pop(rect);
                      },
                      icon: const Icon(Icons.check),
                      label: Text(
                        'Confirm Area (${rect.width.toInt()}x${rect.height.toInt()})',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          // Cancel button floating top-right
          Positioned(
            top: 40,
            right: 20,
            child: IconButton(
              style: IconButton.styleFrom(
                backgroundColor: Colors.black87,
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.close),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Custom painter that draws a semi-transparent dark mask overlay with a clear,
/// highlighted window cutout matching the user's selected area.
class CutoutPainter extends CustomPainter {
  /// Creates a [CutoutPainter] instance with a highlighted [rect] boundary.
  CutoutPainter(this.rect);

  /// The active rectangular region drawn by the user.
  final Rect? rect;

  @override
  void paint(Canvas canvas, Size size) {
    final backgroundPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.65)
      ..style = PaintingStyle.fill;

    if (rect == null) {
      canvas.drawRect(Offset.zero & size, backgroundPaint);
      return;
    }

    // Draw the background with a cutout using evenOdd fill
    final backgroundPath = Path()
      ..addRect(Offset.zero & size)
      ..addRect(rect!)
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(backgroundPath, backgroundPaint);

    // Draw the border around the cutout
    final borderPaint = Paint()
      ..color = Colors.teal
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawRect(rect!, borderPaint);

    // Draw resolution text just above the rect
    final textPainter = TextPainter(
      text: TextSpan(
        text: ' ${rect!.width.toInt()} x ${rect!.height.toInt()} ',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
          backgroundColor: Colors.teal,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();

    // Position text above top-left of rect, or offset down if too close to top
    final textOffset = rect!.top > 25
        ? rect!.topLeft + const Offset(4, -20)
        : rect!.topLeft + const Offset(4, 4);
    textPainter.paint(canvas, textOffset);
  }

  @override
  bool shouldRepaint(covariant CutoutPainter oldDelegate) {
    return oldDelegate.rect != rect;
  }
}
