import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' show LatLng;
import '../../models/checkin_location.dart';
import '../../services/checkin_database.dart';
import '../../services/share_service.dart';
import 'checkin_editor.dart';

LatLng _latLngFromCheckin(CheckInLocation c) => LatLng(c.latitude, c.longitude);

// ── Full-screen swipeable image viewer ───────────────────────────────────────

class _InfoImageViewerScreen extends StatefulWidget {
  final List<String> paths;
  final int initialIndex;

  const _InfoImageViewerScreen({
    required this.paths,
    required this.initialIndex,
  });

  @override
  State<_InfoImageViewerScreen> createState() => _InfoImageViewerScreenState();
}

class _InfoImageViewerScreenState extends State<_InfoImageViewerScreen> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          '${_currentIndex + 1} / ${widget.paths.length}',
          style: const TextStyle(color: Colors.white, fontSize: 15),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.paths.length,
        onPageChanged: (i) => setState(() => _currentIndex = i),
        itemBuilder: (_, i) => InteractiveViewer(
          minScale: 0.5,
          maxScale: 4.0,
          child: Center(
            child: Image.file(File(widget.paths[i]), fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }
}

/// Floating panel shown when the user taps a saved check-in marker.
/// Shows all saved info with Share, Edit, Delete, and Close options.
class CheckInInfoPanel extends StatefulWidget {
  final CheckInLocation checkin;
  final VoidCallback onClose;
  final VoidCallback onEdited;
  final VoidCallback onDeleted;

  const CheckInInfoPanel({
    super.key,
    required this.checkin,
    required this.onClose,
    required this.onEdited,
    required this.onDeleted,
  });

  @override
  State<CheckInInfoPanel> createState() => _CheckInInfoPanelState();
}

class _CheckInInfoPanelState extends State<CheckInInfoPanel> {
  List<String> _resolvedPaths = [];
  bool _isSharing = false;

  @override
  void initState() {
    super.initState();
    _resolvePaths();
  }

  Future<void> _resolvePaths() async {
    final resolved = await CheckInDatabase.resolveMediaPaths(
      widget.checkin.mediaPaths,
    );
    if (mounted) setState(() => _resolvedPaths = resolved);
  }

  // ── Share ─────────────────────────────────────────────────────────────────

  Future<void> _share() async {
    if (_isSharing) return;
    setState(() => _isSharing = true);
    await ShareService.showShareOptions(
      context: context,
      checkIn: widget.checkin,
      resolvedPhotoPaths: _resolvedPaths,
    );
    if (mounted) setState(() => _isSharing = false);
  }

  // ── Delete ────────────────────────────────────────────────────────────────

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFFFFFBEE),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Delete Check-In?',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF3D2000),
          ),
        ),
        content: RichText(
          text: TextSpan(
            style: const TextStyle(
              color: Color(0xFF5C3A00),
              fontSize: 14,
              height: 1.5,
            ),
            children: [
              const TextSpan(text: 'Are you sure you want to delete '),
              TextSpan(
                text: widget.checkin.name ?? widget.checkin.displayLabel,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const TextSpan(text: '? This cannot be undone.'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: TextStyle(color: Colors.brown[400])),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[400],
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await CheckInDatabase.delete(widget.checkin.id);
      widget.onDeleted();
    }
  }

  // ── Weather emoji helper ──────────────────────────────────────────────────

  String _weatherEmoji(String condition) {
    final lc = condition.toLowerCase();
    if (lc.contains('thunderstorm')) return '⛈️';
    if (lc.contains('drizzle')) return '🌦️';
    if (lc.contains('rain')) return '🌧️';
    if (lc.contains('snow')) return '❄️';
    if (lc.contains('clear')) return '☀️';
    if (lc.contains('few clouds')) return '🌤️';
    if (lc.contains('scattered clouds')) return '⛅';
    if (lc.contains('cloud')) return '☁️';
    if (lc.contains('fog') || lc.contains('mist') || lc.contains('haze')) {
      return '🌫️';
    }
    return '🌡️';
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final checkin = widget.checkin;
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return GestureDetector(
      onTap: () {}, // absorb background taps
      child: Align(
        alignment: Alignment.center,
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: screenWidth * 0.88,
            constraints: BoxConstraints(maxHeight: screenHeight * 0.72),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEE),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── Header ─────────────────────────────────────────────
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 18, 12, 14),
                    color: const Color(0xFFFFEFA0),
                    child: Row(
                      children: [
                        Text(
                          checkin.emoji,
                          style: const TextStyle(fontSize: 26),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                checkin.name ?? checkin.displayLabel,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF3D2000),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (checkin.labelWord != null)
                                Text(
                                  checkin.labelWord!,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.brown[400],
                                  ),
                                ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: widget.onClose,
                          icon: const Icon(
                            Icons.close_rounded,
                            color: Color(0xFF975600),
                          ),
                          tooltip: 'Close',
                        ),
                      ],
                    ),
                  ),

                  // ── Body ───────────────────────────────────────────────
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [

                          // ── Weather ──────────────────────────────────
                          if (checkin.weatherDisplay != null) ...[
                            const _SectionLabel(label: 'Weather'),
                            const SizedBox(height: 6),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFD24B)
                                    .withOpacity(0.18),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color(0xFFFFD24B)
                                      .withOpacity(0.55),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Text(
                                    _weatherEmoji(checkin.weatherCondition!),
                                    style: const TextStyle(fontSize: 26),
                                  ),
                                  const SizedBox(width: 12),
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${checkin.weatherTemp!.toStringAsFixed(0)}°C',
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF3D2000),
                                        ),
                                      ),
                                      Text(
                                        checkin.weatherCondition!,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.brown[500],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const Spacer(),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFFD24B)
                                          .withOpacity(0.35),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      'At check-in',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.brown[500],
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),
                          ],

                          // ── Notes ────────────────────────────────────
                          if (checkin.details != null &&
                              checkin.details!.isNotEmpty) ...[
                            const _SectionLabel(label: 'Notes'),
                            const SizedBox(height: 6),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF9C4),
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.06),
                                    blurRadius: 6,
                                    offset: const Offset(2, 3),
                                  ),
                                ],
                              ),
                              child: Text(
                                checkin.details!,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF3D2000),
                                  height: 1.6,
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),
                          ],

                          // ── Photos ───────────────────────────────────
                          if (checkin.mediaPaths.isNotEmpty) ...[
                            const _SectionLabel(label: 'Photos'),
                            const SizedBox(height: 8),
                            SizedBox(
                              height: 100,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: checkin.mediaPaths.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(width: 8),
                                itemBuilder: (ctx, i) {
                                  final path = i < _resolvedPaths.length
                                      ? _resolvedPaths[i]
                                      : checkin.mediaPaths[i];
                                  final file = File(path);
                                  return GestureDetector(
                                    onTap: () => Navigator.push(
                                      ctx,
                                      MaterialPageRoute(
                                        builder: (_) => _InfoImageViewerScreen(
                                          paths: _resolvedPaths.isNotEmpty
                                              ? _resolvedPaths
                                              : checkin.mediaPaths,
                                          initialIndex: i,
                                        ),
                                      ),
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: file.existsSync()
                                          ? Image.file(
                                              file,
                                              width: 100,
                                              height: 100,
                                              fit: BoxFit.cover,
                                            )
                                          : Container(
                                              width: 100,
                                              height: 100,
                                              color: const Color(0xFFFFF3C4),
                                              child: const Icon(
                                                Icons.broken_image,
                                                color: Color(0xFFBBA060),
                                              ),
                                            ),
                                    ),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 14),
                          ],

                          // ── Timestamp ────────────────────────────────
                          Text(
                            'Saved on ${_formatDate(checkin.createdAt)}',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.brown[300],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // ── Action buttons ────────────────────────────
                          Row(
                            children: [
                              // Delete
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => _confirmDelete(context),
                                  icon: const Icon(
                                    Icons.delete_outline_rounded,
                                    size: 18,
                                  ),
                                  label: const Text('Delete'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.red[400],
                                    side: BorderSide(
                                      color: Colors.red[200]!,
                                      width: 1.5,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Share
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _isSharing ? null : _share,
                                  icon: _isSharing
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Color(0xFF975600),
                                          ),
                                        )
                                      : const Icon(
                                          Icons.ios_share_rounded,
                                          size: 18,
                                        ),
                                  label: Text(_isSharing ? '…' : 'Share'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFF975600),
                                    side: const BorderSide(
                                      color: Color(0xFFFFD227),
                                      width: 1.5,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Edit
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    widget.onClose();
                                    showDialog(
                                      context: context,
                                      barrierDismissible: false,
                                      builder: (_) => CheckInEditor(
                                        position: _latLngFromCheckin(
                                          widget.checkin,
                                        ),
                                        existing: widget.checkin,
                                        onSaved: widget.onEdited,
                                      ),
                                    );
                                  },
                                  icon: const Icon(
                                    Icons.edit_rounded,
                                    size: 18,
                                  ),
                                  label: const Text('Edit'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFFFD24B),
                                    foregroundColor: const Color(0xFF3D2000),
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
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

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.bold,
        color: Color(0xFF975600),
      ),
    );
  }
}
