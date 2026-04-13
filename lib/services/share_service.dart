import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:geocoding/geocoding.dart';
import '../models/checkin_location.dart';
import 'noticeboard_service.dart';

class ShareService {
  // ── Public entry points ───────────────────────────────────────────────────

  /// Show bottom sheet with two options:
  /// "Share to Social Media" or "Post to Noticeboard"
  static Future<void> showShareOptions({
    required BuildContext context,
    required CheckInLocation checkIn,
    List<String> resolvedPhotoPaths = const [],
  }) async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _ShareOptionsSheet(
        checkIn: checkIn,
        resolvedPhotoPaths: resolvedPhotoPaths,
      ),
    );
  }

  /// Share a location to social media only — no noticeboard posting.
  static Future<String?> shareToSocialMedia({
    required BuildContext context,
    required CheckInLocation checkIn,
    List<String> resolvedPhotoPaths = const [],
  }) async {
    final city = await _geocodeCity(checkIn.latitude, checkIn.longitude);

    final imageFile = await _renderShareCard(
      context: context,
      emoji: checkIn.emoji,
      labelWord: checkIn.labelWord,
      locationName: checkIn.name,
      details: checkIn.details,
      city: city,
      photoPaths: resolvedPhotoPaths,
      isCollection: false,
    );

    if (imageFile == null) return 'Failed to generate share card.';

    final name = checkIn.name?.isNotEmpty == true
        ? checkIn.name!
        : checkIn.displayLabel;
    final shareText = city != null
        ? 'I visited $name in $city 📍 via My Journey'
        : 'I visited $name 📍 via My Journey';

    await Share.shareXFiles(
      [XFile(imageFile.path)],
      text: shareText,
    );

    return null;
  }

  /// Post a location to the noticeboard only — no social media share sheet.
  static Future<String?> postToNoticeboard({
    required CheckInLocation checkIn,
  }) async {
    final city = await _geocodeCity(checkIn.latitude, checkIn.longitude);

    return await NoticeboardService.postLocation(
      emoji: checkIn.emoji,
      labelWord: checkIn.labelWord,
      locationName: checkIn.name,
      details: checkIn.details,
      city: city,
      latitude: checkIn.latitude,
      longitude: checkIn.longitude,
    );
  }

  // ── Geocoding helper ──────────────────────────────────────────────────────

  static Future<String?> _geocodeCity(double lat, double lng) async {
    try {
      final placemarks = await placemarkFromCoordinates(
        lat, lng, localeIdentifier: 'en_US',
      );
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        final parts = <String>[
          if (p.locality?.isNotEmpty == true) p.locality!,
          if (p.country?.isNotEmpty == true) p.country!,
        ];
        if (parts.isNotEmpty) return parts.join(', ');
      }
    } catch (_) {}
    return null;
  }

  // ── Card renderer ─────────────────────────────────────────────────────────

  static Future<File?> _renderShareCard({
    required BuildContext context,
    required String emoji,
    String? labelWord,
    String? locationName,
    String? details,
    String? city,
    List<String> photoPaths = const [],
    required bool isCollection,
  }) async {
    try {
      final card = _ShareCard(
        emoji: emoji,
        labelWord: labelWord,
        locationName: locationName,
        details: details,
        city: city,
        photoPaths: photoPaths,
        isCollection: isCollection,
      );

      final repaintKey = GlobalKey();
      final completer = ValueNotifier<ui.Image?>(null);

      final overlayEntry = OverlayEntry(
        builder: (_) => Positioned(
          left: -2000,
          top: 0,
          child: RepaintBoundary(
            key: repaintKey,
            child: Material(
              color: Colors.transparent,
              child: card,
            ),
          ),
        ),
      );

      Overlay.of(context).insert(overlayEntry);
      await Future.delayed(const Duration(milliseconds: 300));

      try {
        final boundary = repaintKey.currentContext?.findRenderObject()
            as RenderRepaintBoundary?;
        if (boundary == null) {
          overlayEntry.remove();
          return null;
        }
        final image = await boundary.toImage(pixelRatio: 3.0);
        completer.value = image;
      } finally {
        overlayEntry.remove();
      }

      final img = completer.value;
      if (img == null) return null;

      final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return null;

      final bytes = byteData.buffer.asUint8List();
      final dir = await getTemporaryDirectory();
      final file = File(
        '${dir.path}/my_journey_share_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await file.writeAsBytes(bytes);
      return file;
    } catch (e) {
      return null;
    }
  }
}

// ── Share options bottom sheet ────────────────────────────────────────────────

class _ShareOptionsSheet extends StatefulWidget {
  final CheckInLocation checkIn;
  final List<String> resolvedPhotoPaths;

  const _ShareOptionsSheet({
    required this.checkIn,
    required this.resolvedPhotoPaths,
  });

  @override
  State<_ShareOptionsSheet> createState() => _ShareOptionsSheetState();
}

class _ShareOptionsSheetState extends State<_ShareOptionsSheet> {
  bool _isSharingToSocial = false;
  bool _isPostingToBoard = false;

  Future<void> _shareToSocial() async {
    setState(() => _isSharingToSocial = true);
    final error = await ShareService.shareToSocialMedia(
      context: context,
      checkIn: widget.checkIn,
      resolvedPhotoPaths: widget.resolvedPhotoPaths,
    );
    if (mounted) {
      setState(() => _isSharingToSocial = false);
      Navigator.pop(context);
      if (error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error),
            backgroundColor: const Color(0xFF975600),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 600),
          ),
        );
      }
    }
  }

  Future<void> _postToNoticeboard() async {
    // Show confirmation dialog first
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFFFFFBEE),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Post to Noticeboard?',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF3D2000),
          ),
        ),
        content: Text(
          'Post "${widget.checkIn.name?.isNotEmpty == true ? widget.checkIn.name! : widget.checkIn.displayLabel}" to the public noticeboard? Everyone using My Journey will be able to see and import it.',
          style: TextStyle(
            fontSize: 14,
            color: Colors.brown[600],
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style: TextStyle(color: Colors.brown[400])),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFD24B),
              foregroundColor: const Color(0xFF3D2000),
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Post',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isPostingToBoard = true);
    final error = await ShareService.postToNoticeboard(
      checkIn: widget.checkIn,
    );
    if (mounted) {
      setState(() => _isPostingToBoard = false);
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error ?? 'Posted to the noticeboard!',
          ),
          backgroundColor:
              error != null ? Colors.red : const Color(0xFF975600),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 600),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFFFFBEE),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 36),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.brown[200],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Share this location',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: Color(0xFF3D2000),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            widget.checkIn.name?.isNotEmpty == true
                ? widget.checkIn.name!
                : widget.checkIn.displayLabel,
            style: TextStyle(fontSize: 13, color: Colors.brown[400]),
          ),
          const SizedBox(height: 20),

          // Share to Social Media
          _OptionTile(
            icon: Icons.ios_share_rounded,
            title: 'Share to Social Media',
            subtitle: 'Generate a card and share via WhatsApp, Instagram, etc.',
            isLoading: _isSharingToSocial,
            onTap: _isSharingToSocial || _isPostingToBoard
                ? null
                : _shareToSocial,
          ),
          const SizedBox(height: 12),

          // Post to Noticeboard
          _OptionTile(
            icon: Icons.campaign_rounded,
            title: 'Post to Noticeboard',
            subtitle: 'Share with the My Journey community feed.',
            isLoading: _isPostingToBoard,
            onTap: _isSharingToSocial || _isPostingToBoard
                ? null
                : _postToNoticeboard,
          ),
          const SizedBox(height: 20),

          // Cancel
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(
                foregroundColor: Colors.brown[400],
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text('Cancel', style: TextStyle(fontSize: 15)),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Option tile ───────────────────────────────────────────────────────────────

class _OptionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isLoading;
  final VoidCallback? onTap;

  const _OptionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isLoading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 150),
        opacity: onTap == null ? 0.5 : 1.0,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF3C4),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Icon(icon, color: const Color(0xFF975600), size: 24),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF3D2000),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.brown[400],
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              if (isLoading)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFF975600),
                  ),
                )
              else
                Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.brown[300],
                  size: 20,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Share card widget ─────────────────────────────────────────────────────────

class _ShareCard extends StatelessWidget {
  final String emoji;
  final String? labelWord;
  final String? locationName;
  final String? details;
  final String? city;
  final List<String> photoPaths;
  final bool isCollection;

  const _ShareCard({
    required this.emoji,
    this.labelWord,
    this.locationName,
    this.details,
    this.city,
    this.photoPaths = const [],
    required this.isCollection,
  });

  @override
  Widget build(BuildContext context) {
    // Filter to only existing files
    final validPhotos = photoPaths
        .where((p) => File(p).existsSync())
        .toList();

    return SizedBox(
      width: 380,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFFFFBEE),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        clipBehavior: Clip.hardEdge,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Orange header bar ────────────────────────────────────
            Container(
              color: const Color(0xFFE05A00),
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(emoji, style: const TextStyle(fontSize: 32)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          locationName?.isNotEmpty == true
                              ? locationName!
                              : (labelWord?.isNotEmpty == true
                                  ? labelWord!
                                  : 'My Journey'),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            height: 1.2,
                          ),
                        ),
                        if (labelWord?.isNotEmpty == true && !isCollection)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              labelWord!,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.white.withOpacity(0.85),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── Text info section ────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // City
                  if (city != null) ...[
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          size: 15,
                          color: Color(0xFFE05A00),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            city!,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF3E1F00),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                  ],

                  // Details / notes — full text, no truncation
                  if (details?.isNotEmpty == true) ...[
                    Text(
                      details!,
                      style: TextStyle(
                        fontSize: 13,
                        color: const Color(0xFF3E1F00).withOpacity(0.75),
                        height: 1.55,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    const SizedBox(height: 14),
                  ] else
                    const SizedBox(height: 6),
                ],
              ),
            ),

            // ── Photos — all stacked full-width, no cropping ──────────
            if (validPhotos.isNotEmpty) ...[
              for (final path in validPhotos)
                Image.file(
                  File(path),
                  width: 380,
                  fit: BoxFit.fitWidth, // full width, natural height
                ),
              const SizedBox(height: 0),
            ],

            // ── Branding footer ──────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
              child: Column(
                children: [
                  Container(
                    height: 1,
                    color: const Color(0xFFFFD227).withOpacity(0.5),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFD227),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Center(
                          child: Text('🗺️',
                              style: TextStyle(fontSize: 14)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'My Journey',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF3E1F00),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        _formatDate(DateTime.now()),
                        style: TextStyle(
                          fontSize: 11,
                          color: const Color(0xFF3E1F00).withOpacity(0.45),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }
}