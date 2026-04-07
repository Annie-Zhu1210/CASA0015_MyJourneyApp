// lib/screens/location_detail_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' show LatLng;
import '../models/checkin_location.dart';
import '../services/checkin_database.dart';
import '../widgets/checkin/checkin_editor.dart';

LatLng _latLngFromCheckin(CheckInLocation c) => LatLng(c.latitude, c.longitude);

/// Full-screen detail view for a saved check-in, opened from the
/// Locations screen with a right-to-left slide transition.
class LocationDetailScreen extends StatefulWidget {
  final CheckInLocation checkIn;

  /// Called after a successful edit or delete so the parent list refreshes.
  final VoidCallback onChanged;

  const LocationDetailScreen({
    super.key,
    required this.checkIn,
    required this.onChanged,
  });

  @override
  State<LocationDetailScreen> createState() => _LocationDetailScreenState();
}

class _LocationDetailScreenState extends State<LocationDetailScreen> {
  // We keep a local mutable copy so edits reflect immediately on this screen
  // without needing to pop and re-open.
  late CheckInLocation _checkIn;

  @override
  void initState() {
    super.initState();
    _checkIn = widget.checkIn;
  }

  // ── Delete ───────────────────────────────────────────────────────────────

  Future<void> _confirmDelete() async {
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
                color: Color(0xFF5C3A00), fontSize: 14, height: 1.5),
            children: [
              const TextSpan(text: 'Are you sure you want to delete '),
              TextSpan(
                text: _checkIn.name ?? _checkIn.displayLabel,
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
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await CheckInDatabase.delete(_checkIn.id);
      widget.onChanged();
      if (mounted) Navigator.pop(context);
    }
  }

  // ── Edit ─────────────────────────────────────────────────────────────────

  Future<void> _openEditor() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => CheckInEditor(
        position: _latLngFromCheckin(_checkIn),
        existing: _checkIn,
        onSaved: () async {
          // Reload from DB so local copy reflects the edit
          final updated = await CheckInDatabase.loadAll();
          final fresh =
              updated.where((c) => c.id == _checkIn.id).firstOrNull;
          if (fresh != null && mounted) {
            setState(() => _checkIn = fresh);
          }
          widget.onChanged();
        },
      ),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  String _formatDate(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F0),
      body: SafeArea(
        child: Column(
          children: [
            // ── Header bar ───────────────────────────────────────────────
            _buildHeader(),

            // ── Scrollable body ──────────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Label pill
                    _buildLabelPill(),
                    const SizedBox(height: 20),

                    // Coordinates
                    _buildCoordRow(),
                    const SizedBox(height: 20),

                    // Notes
                    if (_checkIn.details != null &&
                        _checkIn.details!.isNotEmpty) ...[
                      _sectionLabel('Notes'),
                      const SizedBox(height: 8),
                      _buildNotesCard(),
                      const SizedBox(height: 20),
                    ],

                    // Photos
                    if (_checkIn.mediaPaths.isNotEmpty) ...[
                      _sectionLabel('Photos'),
                      const SizedBox(height: 8),
                      _buildPhotoStrip(),
                      const SizedBox(height: 20),
                    ],

                    // Timestamp
                    Text(
                      'Saved on ${_formatDate(_checkIn.createdAt)}',
                      style: TextStyle(
                          fontSize: 12,
                          color: const Color(0xFF3E1F00).withOpacity(0.4)),
                    ),
                    const SizedBox(height: 28),

                    // Action buttons
                    _buildActionButtons(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Sub-widgets ───────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Container(
      color: const Color(0xFFFFEFA0),
      padding: const EdgeInsets.fromLTRB(4, 10, 16, 10),
      child: Row(
        children: [
          // Back button
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                color: Color(0xFF975600), size: 20),
            tooltip: 'Back',
          ),
          // Emoji
          Text(_checkIn.emoji, style: const TextStyle(fontSize: 28)),
          const SizedBox(width: 10),
          // Name
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _checkIn.name?.isNotEmpty == true
                      ? _checkIn.name!
                      : _checkIn.displayLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF3D2000),
                    letterSpacing: -0.3,
                  ),
                ),
                if (_checkIn.labelWord != null &&
                    _checkIn.labelWord!.isNotEmpty)
                  Text(
                    _checkIn.labelWord!,
                    style: TextStyle(fontSize: 12, color: Colors.brown[400]),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabelPill() {
    return Wrap(
      children: [
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: const Color(0xFFFFD227),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            _checkIn.displayLabel,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFF3E1F00),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCoordRow() {
    return Row(
      children: [
        Icon(Icons.location_on_outlined,
            size: 16, color: const Color(0xFFB87000).withOpacity(0.7)),
        const SizedBox(width: 5),
        Text(
          '${_checkIn.latitude.toStringAsFixed(5)}, '
          '${_checkIn.longitude.toStringAsFixed(5)}',
          style: TextStyle(
            fontSize: 13,
            color: const Color(0xFF3E1F00).withOpacity(0.45),
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }

  Widget _buildNotesCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF9C4),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Text(
        _checkIn.details!,
        style: const TextStyle(
          fontSize: 14,
          color: Color(0xFF3D2000),
          height: 1.65,
        ),
      ),
    );
  }

  Widget _buildPhotoStrip() {
    return SizedBox(
      height: 110,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _checkIn.mediaPaths.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (ctx, i) {
          final file = File(_checkIn.mediaPaths[i]);
          return GestureDetector(
            onTap: () => Navigator.push(
              ctx,
              MaterialPageRoute(
                builder: (_) => _FullScreenImageViewer(
                  paths: _checkIn.mediaPaths,
                  initialIndex: i,
                ),
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: file.existsSync()
                  ? Image.file(file,
                      width: 110, height: 110, fit: BoxFit.cover)
                  : Container(
                      width: 110,
                      height: 110,
                      color: const Color(0xFFFFF3C4),
                      child: const Icon(Icons.broken_image,
                          color: Color(0xFFBBA060)),
                    ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        // Delete
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _confirmDelete,
            icon: const Icon(Icons.delete_outline_rounded, size: 18),
            label: const Text('Delete'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red[400],
              side: BorderSide(color: Colors.red[200]!, width: 1.5),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
        const SizedBox(width: 12),
        // Edit
        Expanded(
          flex: 2,
          child: ElevatedButton.icon(
            onPressed: _openEditor,
            icon: const Icon(Icons.edit_rounded, size: 18),
            label: const Text('Edit'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFD24B),
              foregroundColor: const Color(0xFF3D2000),
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
      ],
    );
  }

  Widget _sectionLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: Color(0xFF975600),
        letterSpacing: 0.2,
      ),
    );
  }
}

// ── Full-screen image viewer ──────────────────────────────────────────────────

class _FullScreenImageViewer extends StatefulWidget {
  final List<String> paths;
  final int initialIndex;

  const _FullScreenImageViewer({
    required this.paths,
    required this.initialIndex,
  });

  @override
  State<_FullScreenImageViewer> createState() =>
      _FullScreenImageViewerState();
}

class _FullScreenImageViewerState extends State<_FullScreenImageViewer> {
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
            child: Image.file(
              File(widget.paths[i]),
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    );
  }
}