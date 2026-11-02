// Dart Imports
import 'dart:math' as math;

// Flutter Imports
import "package:flutter/material.dart";

// Project Imports
import "package:ltc/core/game/data_entities.dart";
import "package:ltc/features/calculator/providers/build_state_provider.dart";

class TalentDependencyPainter extends CustomPainter {
  final Map<Talent, Offset> centers;
  final Map<Talent, List<Talent>> supports;
  final double arrowHeadSize;
  final double arrowOffset;
  final BuildState buildState;
  final Color expColor;
  final double strokeWidth;
  final bool reverseDirection;
  final double headForwardFactor;
  final double headBackwardFactor;

  TalentDependencyPainter({
    required this.centers,
    required this.supports,
    required this.buildState,
    this.arrowHeadSize = 20,
    this.arrowOffset = 32,
    this.expColor = Colors.white,
    this.strokeWidth = 3,
    this.reverseDirection = true,
    this.headForwardFactor = 0,
    this.headBackwardFactor = 1,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final entry in supports.entries) {
      final child = entry.key;
      final prereqs = entry.value;
      final childCenter = centers[child];
      if (childCenter == null) continue;

      for (final talent in prereqs) {
        Color color = Colors.grey;
        if (buildState.isTalentEnabled(talent) ||
            talent.currentRank == talent.ranks.length) {
          color = expColor;
        }

        final linePaint = Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round;

        final headPaint = Paint()
          ..color = color
          ..style = PaintingStyle.fill;

        final srcCenter = centers[talent];
        if (srcCenter == null) continue;

        final dx = childCenter.dx - srcCenter.dx;
        final dy = childCenter.dy - srcCenter.dy;

        final isStraight = dx.abs() < 1e-3 || dy.abs() < 1e-3;

        if (isStraight) {
          // Unified straight-line handling (fixes right->left horizontal offset)
          // Determine arrow direction (where the arrow head will be).
          // reverseDirection=true means arrow points from child -> prerequisite (original behavior).
          final dirVector = reverseDirection
              ? (srcCenter - childCenter)
              : (childCenter - srcCenter);
          if (dirVector.distance == 0) continue;
          final unit = dirVector / dirVector.distance;

          final startPoint = reverseDirection ? childCenter : srcCenter;
          final endPoint = reverseDirection ? srcCenter : childCenter;

          // Shrink line slightly to not overlap icon centers
          const inset = 1.0;
          final start = startPoint + unit * inset;
          final end = endPoint - unit * inset;

          final totalLen = (end - start).distance;
          // Keep arrow offsets within reasonable bounds
          final effectiveOffset = math.min(arrowOffset, totalLen * 0.45);

          final anchor = end - unit * effectiveOffset; // Where head sits
          final from = start + unit * effectiveOffset; // Opposite side ref

          canvas.drawLine(start, end, linePaint);

          _drawArrowHeadCenteredAtAnchor(
            canvas,
            anchor: anchor,
            from: from,
            paint: headPaint,
          );
        } else {
          // L shape (vertical then horizontal) unchanged
          final signX = dx.sign;
          final signY = dy.sign;

          final vertStart = srcCenter + Offset(0, signY);
          final vertEndRaw = Offset(srcCenter.dx, childCenter.dy);
          final vertEnd = vertEndRaw - Offset(0, signY);

          final horizEndRaw = Offset(childCenter.dx, vertEnd.dy);
          final horizEnd = horizEndRaw - Offset(signX, 0);

          final path = Path()
            ..moveTo(vertStart.dx, vertStart.dy)
            ..lineTo(vertEnd.dx, vertEnd.dy)
            ..lineTo(horizEnd.dx, horizEnd.dy);
          canvas.drawPath(path, linePaint);

          _drawArrowHeadCenteredAtAnchor(
            canvas,
            anchor: reverseDirection
                ? srcCenter + Offset(0, signY - arrowOffset)
                : horizEndRaw - Offset(signX - arrowOffset, 0),
            from: vertEndRaw - Offset(0, signY - arrowOffset),
            paint: headPaint,
          );
        }
      }
    }
  }

  // Anchor = point where line stops (image border). Arrow head centered on this anchor:
  // part extends forward (toward tip), part backward over the line so the line visually
  // ends inside the head.
  void _drawArrowHeadCenteredAtAnchor(
    Canvas canvas, {
    required Offset anchor,
    required Offset from,
    required Paint paint,
  }) {
    final dirVec = anchor - from;
    if (dirVec.distance <= 0.0001) return;
    final unit = dirVec / dirVec.distance;
    final perp = Offset(-unit.dy, unit.dx);

    final forward = arrowHeadSize * headForwardFactor;
    final backward = arrowHeadSize * headBackwardFactor;

    final baseCenter = anchor - unit * backward;
    final tip = anchor + unit * forward;

    final left = baseCenter + perp * (arrowHeadSize * 0.4);
    final right = baseCenter - perp * (arrowHeadSize * 0.4);

    final head = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(left.dx, left.dy)
      ..lineTo(right.dx, right.dy)
      ..close();
    canvas.drawPath(head, paint);
  }

  @override
  bool shouldRepaint(covariant TalentDependencyPainter oldDelegate) {
    return oldDelegate.centers != centers ||
        oldDelegate.supports != supports ||
        oldDelegate.expColor != expColor ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.reverseDirection != reverseDirection ||
        oldDelegate.arrowHeadSize != arrowHeadSize ||
        oldDelegate.headForwardFactor != headForwardFactor ||
        oldDelegate.headBackwardFactor != headBackwardFactor;
  }
}
