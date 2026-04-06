// lib/services/checkin_marker_builder.dart
//
// Draws a white circle with an emoji inside and a downward teardrop tail,
// matching the Google Maps style marker shown in the design reference.

import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class CheckInMarkerBuilder {
  /// Builds a [BitmapDescriptor] for a check-in marker.
  /// [emoji] is the character(s) to draw in the circle.
  static Future<BitmapDescriptor> build(String emoji) async {
    const double circleRadius = 28.0;
    const double tailHeight = 12.0;
    const double tailWidth = 14.0;
    const double padding = 4.0; // anti-clipping padding around shadow
    const double shadowBlur = 6.0;

    final double totalWidth = (circleRadius * 2) + padding * 2 + shadowBlur * 2;
    final double totalHeight =
        (circleRadius * 2) + tailHeight + padding * 2 + shadowBlur * 2;

    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder);

    final double cx = totalWidth / 2;
    final double cy = circleRadius + padding + shadowBlur;

    // ── Shadow ──────────────────────────────────────────────────────────────
    final Paint shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.22)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, shadowBlur);

    final Path bubblePath = _buildBubblePath(
      cx: cx,
      cy: cy,
      radius: circleRadius,
      tailHeight: tailHeight,
      tailWidth: tailWidth,
    );
    canvas.drawPath(bubblePath, shadowPaint);

    // ── White bubble ────────────────────────────────────────────────────────
    final Paint whitePaint = Paint()..color = Colors.white;
    canvas.drawPath(bubblePath, whitePaint);

    // ── Emoji text ───────────────────────────────────────────────────────────
    final ui.ParagraphBuilder pb = ui.ParagraphBuilder(
      ui.ParagraphStyle(
        fontSize: 22,
        textAlign: TextAlign.center,
      ),
    )..addText(emoji);

    final ui.Paragraph paragraph = pb.build()
      ..layout(ui.ParagraphConstraints(width: circleRadius * 2));

    canvas.drawParagraph(
      paragraph,
      Offset(cx - circleRadius, cy - paragraph.height / 2 - 1),
    );

    // ── Finalise ─────────────────────────────────────────────────────────────
    final ui.Image image = await recorder
        .endRecording()
        .toImage(totalWidth.round(), totalHeight.round());

    final byteData =
        await image.toByteData(format: ui.ImageByteFormat.png);

    return BitmapDescriptor.bytes(
      byteData!.buffer.asUint8List(),
    );
  }

  static Path _buildBubblePath({
    required double cx,
    required double cy,
    required double radius,
    required double tailHeight,
    required double tailWidth,
  }) {
    final Path path = Path();

    // Circle
    path.addOval(Rect.fromCircle(center: Offset(cx, cy), radius: radius));

    // Downward tail (triangle)
    path.moveTo(cx - tailWidth / 2, cy + radius - 4);
    path.lineTo(cx, cy + radius + tailHeight);
    path.lineTo(cx + tailWidth / 2, cy + radius - 4);
    path.close();

    return path;
  }
}