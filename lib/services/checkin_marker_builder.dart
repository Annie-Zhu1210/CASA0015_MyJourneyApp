import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class CheckInMarkerBuilder {
  static Future<BitmapDescriptor> build(
    String emoji, {
    double scale = 1.0,
  }) async {
    scale = scale.clamp(0.35, 1.0);

    // Base dimensions (at scale 1.0)
    const double baseCircleRadius = 28.0;
    const double baseTailHeight = 12.0;
    const double baseTailWidth = 14.0;
    const double basePadding = 4.0;
    const double baseShadowBlur = 6.0;
    const double baseFont = 22.0;

    final double circleRadius = baseCircleRadius * scale;
    final double tailHeight = baseTailHeight * scale;
    final double tailWidth = baseTailWidth * scale;
    final double padding = basePadding * scale;
    final double shadowBlur = baseShadowBlur * scale;
    final double fontSize = baseFont * scale;

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
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, shadowBlur);

    final Path bubblePath = _buildBubblePath(
      cx: cx,
      cy: cy,
      radius: circleRadius,
      tailHeight: tailHeight,
      tailWidth: tailWidth,
    );
    canvas.drawPath(bubblePath, shadowPaint);

    // ── White bubble ────────────────────────────────────────────────────────
    canvas.drawPath(bubblePath, Paint()..color = Colors.white);

    // ── Emoji text ───────────────────────────────────────────────────────────
    final ui.ParagraphBuilder pb = ui.ParagraphBuilder(
      ui.ParagraphStyle(
        fontSize: fontSize,
        textAlign: TextAlign.center,
      ),
    )..addText(emoji);

    final ui.Paragraph paragraph = pb.build()
      ..layout(ui.ParagraphConstraints(width: circleRadius * 2));

    canvas.drawParagraph(
      paragraph,
      Offset(cx - circleRadius, cy - paragraph.height / 2 - 1 * scale),
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
    path.addOval(Rect.fromCircle(center: Offset(cx, cy), radius: radius));
    path.moveTo(cx - tailWidth / 2, cy + radius - 4);
    path.lineTo(cx, cy + radius + tailHeight);
    path.lineTo(cx + tailWidth / 2, cy + radius - 4);
    path.close();
    return path;
  }
}