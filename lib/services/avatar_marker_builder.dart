import 'dart:ui' as ui;
import 'dart:io' as io;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

class AvatarMarkerBuilder {
  // ── Base dimensions at scale 1.0 ──────────────────────────────────────────
  static const double _markerSize   = 72.0;
  static const double _borderWidth  = 3.5;
  static const double _cornerRadius = 32.0;
  static const double _tailHeight   = 14.0;
  static const double _tailWidth    = 16.0;
  static const double _shadowBlur   = 7.0;
  static const double _padding      = 4.0;

  static const Color _borderColor = Color(0xFFE05A00);
  static const Color _shadowColor = Color(0x44000000);

  /// Builds an avatar [BitmapDescriptor].
  ///
  /// [photoUrl]         — network URL or local file path; null → initial fallback.
  /// [displayName]      — used to derive the fallback initial letter.
  /// [scale]            — zoom-driven size factor, clamped to [0.5, 1.0].
  /// [devicePixelRatio] — passed from the Flutter window for crisp rendering.
  static Future<BitmapDescriptor> build({
    String? photoUrl,
    String displayName = '?',
    double scale = 1.0,
    double devicePixelRatio = 2.0,
  }) async {
    scale = scale.clamp(0.5, 1.0);

    ui.Image? avatarImage;
    if (photoUrl != null && photoUrl.isNotEmpty) {
      avatarImage = await _loadImage(photoUrl);
    }

    return _render(
      avatarImage: avatarImage,
      initial: _initial(displayName),
      scale: scale,
      devicePixelRatio: devicePixelRatio,
    );
  }

  // ── Internals ─────────────────────────────────────────────────────────────

  static String _initial(String name) {
    final t = name.trim();
    return t.isEmpty ? '?' : t[0].toUpperCase();
  }

  static Future<ui.Image?> _loadImage(String source) async {
    try {
      Uint8List bytes;
      if (source.startsWith('/') || source.startsWith('file://')) {
        bytes = await io.File(source.replaceFirst('file://', '')).readAsBytes();
      } else if (source.startsWith('http')) {
        final response = await http.get(Uri.parse(source));
        if (response.statusCode != 200) return null;
        bytes = response.bodyBytes;
      } else {
        return null;
      }
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      return frame.image;
    } catch (_) {
      return null;
    }
  }

  static Future<BitmapDescriptor> _render({
    required ui.Image? avatarImage,
    required String initial,
    required double scale,
    required double devicePixelRatio,
  }) async {
    final double rs = scale * devicePixelRatio;

    final double s      = _markerSize   * rs;
    final double border = _borderWidth  * rs;
    final double radius = _cornerRadius * rs;
    final double tail   = _tailHeight   * rs;
    final double tailW  = _tailWidth    * rs;
    final double shadow = _shadowBlur   * rs;
    final double pad    = _padding      * rs;

    final double totalW = s + pad * 2 + shadow * 2;
    final double totalH = s + tail + pad * 2 + shadow * 2;

    final recorder = ui.PictureRecorder();
    final canvas   = Canvas(recorder);

    final double left = pad + shadow;
    final double top  = pad + shadow;
    final double cx   = left + s / 2;

    // ── Drop shadow ───────────────────────────────────────────────────────
    final shadowPaint = Paint()
      ..color      = _shadowColor
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, shadow);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(left, top, s, s), Radius.circular(radius)),
      shadowPaint,
    );
    final tailPath = _tailPath(cx, top + s - 2 * rs, tail, tailW);
    canvas.drawPath(tailPath, shadowPaint);

    // ── Orange border ─────────────────────────────────────────────────────
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(left, top, s, s), Radius.circular(radius)),
      Paint()..color = _borderColor,
    );

    // ── White inner background ────────────────────────────────────────────
    final innerLeft   = left + border;
    final innerTop    = top  + border;
    final innerSize   = s - border * 2;
    final innerRect   = RRect.fromRectAndRadius(
      Rect.fromLTWH(innerLeft, innerTop, innerSize, innerSize),
      Radius.circular((radius - border).clamp(0, double.infinity)),
    );
    canvas.drawRRect(innerRect, Paint()..color = Colors.white);

    // ── Avatar photo (centre-crop) or initial letter ──────────────────────
    canvas.save();
    canvas.clipRRect(innerRect);

    if (avatarImage != null) {
      // Centre-crop: preserve aspect ratio, fill the square (like BoxFit.cover)
      final imgW = avatarImage.width.toDouble();
      final imgH = avatarImage.height.toDouble();
      final imgAspect = imgW / imgH;
      final dstAspect = 1.0; // destination is always square

      double srcX, srcY, srcW, srcH;
      if (imgAspect > dstAspect) {
        // Image is wider than square — crop sides
        srcH = imgH;
        srcW = imgH * dstAspect;
        srcX = (imgW - srcW) / 2;
        srcY = 0;
      } else {
        // Image is taller than square — crop top/bottom
        srcW = imgW;
        srcH = imgW / dstAspect;
        srcX = 0;
        srcY = (imgH - srcH) / 2;
      }

      final src = Rect.fromLTWH(srcX, srcY, srcW, srcH);
      final dst = Rect.fromLTWH(innerLeft, innerTop, innerSize, innerSize);
      canvas.drawImageRect(avatarImage, src, dst, Paint());
    } else {
      // Warm tint background
      canvas.drawRRect(
          innerRect,
          Paint()..color = const Color(0xFFFFCD27).withOpacity(0.25));

      // Initial letter, vertically centred
      final fontSize = innerSize * 0.42;
      final pb = ui.ParagraphBuilder(
        ui.ParagraphStyle(
          fontSize:   fontSize,
          textAlign:  TextAlign.center,
          fontWeight: FontWeight.w700,
        ),
      )
        ..pushStyle(ui.TextStyle(
          color:      const Color(0xFF7A3D00),
          fontWeight: FontWeight.w700,
        ))
        ..addText(initial);

      final para = pb.build()
        ..layout(ui.ParagraphConstraints(width: innerSize));

      canvas.drawParagraph(
        para,
        Offset(innerLeft, innerTop + (innerSize - para.height) / 2),
      );
    }

    canvas.restore();

    // ── Orange tail ───────────────────────────────────────────────────────
    canvas.drawPath(tailPath, Paint()..color = _borderColor);

    // ── Finalise ──────────────────────────────────────────────────────────
    final image = await recorder
        .endRecording()
        .toImage(totalW.round(), totalH.round());

    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

    return BitmapDescriptor.bytes(
      byteData!.buffer.asUint8List(),
      width:  totalW / devicePixelRatio,
      height: totalH / devicePixelRatio,
    );
  }

  static Path _tailPath(double cx, double tipY, double tailH, double tailW) {
    return Path()
      ..moveTo(cx - tailW / 2, tipY)
      ..lineTo(cx, tipY + tailH)
      ..lineTo(cx + tailW / 2, tipY)
      ..close();
  }
}