import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import '../../models/checkin_location.dart';
import '../../services/checkin_database.dart';
import 'label_picker.dart';
// ClearableValue is defined in checkin_location.dart and imported above

/// Level 2 floating panel — full check-in editor.
/// Used for both creating a new check-in and editing an existing one.
class CheckInEditor extends StatefulWidget {
  final LatLng position;
  final CheckInLocation? existing; // null = new check-in
  final VoidCallback onSaved;

  const CheckInEditor({
    super.key,
    required this.position,
    this.existing,
    required this.onSaved,
  });

  @override
  State<CheckInEditor> createState() => _CheckInEditorState();
}

class _CheckInEditorState extends State<CheckInEditor> {
  // ── Form state ────────────────────────────────────────────────────────────
  String? _emoji;
  String? _labelWord;
  String? _name;
  String? _details;
  List<String> _mediaPaths = [];

  bool _hasChanges = false;
  bool _isSaving = false;
  // Resolved full paths for thumbnail preview — kept in sync with _mediaPaths
  List<String> _resolvedPaths = [];

  @override
  void initState() {
    super.initState();
    if (widget.existing != null) {
      final e = widget.existing!;
      _emoji = e.emoji;
      _labelWord = e.labelWord;
      _name = e.name;
      _details = e.details;
      _mediaPaths = List.from(e.mediaPaths);
    }
    _resolveExistingPaths();
  }

  Future<void> _resolveExistingPaths() async {
    final resolved = await CheckInDatabase.resolveMediaPaths(_mediaPaths);
    if (mounted) setState(() => _resolvedPaths = resolved);
  }

  void _markChanged() => _hasChanges = true;

  // ── Label picker ──────────────────────────────────────────────────────────
  Future<void> _openLabelPicker() async {
    final result = await showLabelPicker(context);
    if (result == null) return;

    if (result['emoji'] == '__custom__') {
      _openEmojiKeyboard();
      return;
    }

    setState(() {
      _emoji = result['emoji'];
      _labelWord = result['word'];
      _markChanged();
    });
  }

  void _openEmojiKeyboard() {
    showDialog(
      context: context,
      builder: (ctx) => _EmojiInputDialog(
        onEmojiSelected: (emoji) {
          setState(() {
            _emoji = emoji;
            _labelWord = null;
            _markChanged();
          });
        },
      ),
    );
  }

  // ── Name input ────────────────────────────────────────────────────────────
  Future<void> _openNameInput() async {
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => _NameInputDialog(initialValue: _name),
    );
    if (result != null) {
      setState(() {
        _name = result.isEmpty ? null : result;
        _markChanged();
      });
    }
  }

  // ── Details editor ────────────────────────────────────────────────────────
  Future<void> _openDetailsEditor() async {
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => _DetailsDialog(initialValue: _details),
    );
    if (result != null) {
      setState(() {
        _details = result.isEmpty ? null : result;
        _markChanged();
      });
    }
  }

  // ── Permanent storage helper ──────────────────────────────────────────────
  /// Copies a file from its current path (which may be a tmp/ location that
  /// iOS can delete at any time) into the app's permanent Documents directory.
  /// Returns the new permanent path.
  Future<String> _copyToAppDir(String sourcePath) async {
    final dir = await getApplicationDocumentsDirectory();
    final photosDir = Directory(p.join(dir.path, 'checkin_photos'));
    if (!photosDir.existsSync()) {
      photosDir.createSync(recursive: true);
    }
    final ext = p.extension(sourcePath).isNotEmpty
        ? p.extension(sourcePath)
        : '.jpg';
    // Use a UUID filename so it is unique and collision-free
    final fileName = '${const Uuid().v4()}$ext';
    final destPath = p.join(photosDir.path, fileName);
    await File(sourcePath).copy(destPath);
    // Return the full path — caller stores filename in DB and full path
    // in _resolvedPaths for immediate preview.
    return destPath;
  }

  // ── Media upload — multi-select from gallery, single from camera ──────────
  Future<void> _openMediaPicker() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFFFFFBEE),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.brown[200],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            _MediaOptionTile(
              icon: Icons.photo_library_rounded,
              label: 'Choose from Gallery',
              onTap: () => Navigator.pop(ctx, 'gallery'),
            ),
            const SizedBox(height: 12),
            _MediaOptionTile(
              icon: Icons.camera_alt_rounded,
              label: 'Take Photo / Video',
              onTap: () => Navigator.pop(ctx, 'camera'),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );

    if (choice == null) return;

    final picker = ImagePicker();

    try {
      if (choice == 'gallery') {
        // Multi-select: iOS shows native multi-select picker with a confirm button
        final files = await picker.pickMultiImage(imageQuality: 90);
        if (files.isNotEmpty && mounted) {
          // Copy every file out of tmp/ into permanent Documents storage
          final fullPaths = await Future.wait(
            files.map((f) => _copyToAppDir(f.path)),
          );
          setState(() {
            // DB stores only the filename; _resolvedPaths stores full path for preview
            _mediaPaths = [..._mediaPaths, ...fullPaths.map(p.basename)];
            _resolvedPaths = [..._resolvedPaths, ...fullPaths];
            _markChanged();
          });
        }
      } else {
        // Camera: single capture
        final file = await picker.pickImage(source: ImageSource.camera);
        if (file != null && mounted) {
          // Copy out of tmp/ into permanent Documents storage
          final fullPath = await _copyToAppDir(file.path);
          setState(() {
            _mediaPaths = [..._mediaPaths, p.basename(fullPath)];
            _resolvedPaths = [..._resolvedPaths, fullPath];
            _markChanged();
          });
        }
      }
    } on PlatformException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Media access permission denied.')),
        );
      }
    }
  }

  void _removeMedia(int index) {
    setState(() {
      _mediaPaths = List.from(_mediaPaths)..removeAt(index);
      if (index < _resolvedPaths.length) {
        _resolvedPaths = List.from(_resolvedPaths)..removeAt(index);
      }
      _markChanged();
    });
  }

  // ── Full-screen image viewer ──────────────────────────────────────────────
  void _openImageViewer(int initialIndex) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _ImageViewerScreen(
          paths: _resolvedPaths.isNotEmpty ? _resolvedPaths : _mediaPaths,
          initialIndex: initialIndex,
        ),
      ),
    );
  }

  // ── Save ──────────────────────────────────────────────────────────────────
  Future<void> _save() async {
    if (_emoji == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a label emoji first.'),
          backgroundColor: Color(0xFF975600),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    final now = DateTime.now();
    final checkin = widget.existing == null
        ? CheckInLocation(
            id: const Uuid().v4(),
            latitude: widget.position.latitude,
            longitude: widget.position.longitude,
            emoji: _emoji!,
            labelWord: _labelWord,
            name: _name,
            details: _details,
            mediaPaths: _mediaPaths,
            createdAt: now,
            updatedAt: now,
          )
        : widget.existing!.copyWith(
            emoji: _emoji,
            labelWord: ClearableValue(_labelWord),
            name: ClearableValue(_name),
            details: ClearableValue(_details),
            mediaPaths: _mediaPaths,
            updatedAt: now,
          );

    if (widget.existing == null) {
      await CheckInDatabase.insert(checkin);
    } else {
      await CheckInDatabase.update(checkin);
    }

    if (mounted) {
      Navigator.pop(context);
      widget.onSaved();
    }
  }

  // ── Exit with unsaved-changes guard ──────────────────────────────────────
  Future<void> _tryExit() async {
    if (!_hasChanges) {
      Navigator.pop(context);
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => _UnsavedChangesDialog(),
    );
    if (confirmed == true && mounted) Navigator.pop(context);
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existing != null;
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    // Issue 3: GestureDetector absorbs taps so clicking outside the card
    // does NOT close the window — only the X button can close it.
    // Issue 4: Align(center) ensures true vertical centering regardless
    // of content height.
    return GestureDetector(
      onTap: () {}, // absorb background taps
      child: Align(
        alignment: Alignment.center,
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: screenWidth * 0.88,
            constraints: BoxConstraints(maxHeight: screenHeight * 0.75),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEE),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
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
                  // ── Header ────────────────────────────────────────────
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 18, 12, 14),
                    color: const Color(0xFFFFEFA0),
                    child: Row(
                      children: [
                        const Icon(Icons.place_rounded,
                            color: Color(0xFF975600), size: 22),
                        const SizedBox(width: 8),
                        Text(
                          isEditing ? 'Edit Check-In' : 'New Check-In',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF3D2000),
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: _tryExit,
                          icon: const Icon(Icons.close_rounded,
                              color: Color(0xFF975600)),
                          tooltip: 'Exit',
                        ),
                      ],
                    ),
                  ),

                  // ── Scrollable body ──────────────────────────────────
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Preview row
                          if (_emoji != null || _name != null)
                            _PreviewBanner(
                                emoji: _emoji,
                                name: _name,
                                word: _labelWord),

                          // Issue 5: removed leading emoji icons from buttons
                          GridView.count(
                            crossAxisCount: 2,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                            childAspectRatio: 2.6,
                            children: [
                              _ActionButton(
                                label: _emoji != null
                                    ? '$_emoji${_labelWord != null ? " $_labelWord" : ""}'
                                    : 'Label *',
                                isRequired: true,
                                isFilled: _emoji != null,
                                onTap: _openLabelPicker,
                              ),
                              _ActionButton(
                                label: _name ?? 'Name',
                                isFilled: _name != null,
                                onTap: _openNameInput,
                              ),
                              _ActionButton(
                                label: _details != null
                                    ? 'Note added ✓'
                                    : 'Details',
                                isFilled: _details != null,
                                onTap: _openDetailsEditor,
                              ),
                              _ActionButton(
                                label: _mediaPaths.isEmpty
                                    ? 'Upload'
                                    : '${_mediaPaths.length} photo(s)',
                                isFilled: _mediaPaths.isNotEmpty,
                                onTap: _openMediaPicker,
                              ),
                            ],
                          ),

                          // Issue 2: thumbnails are now tappable for full view
                          if (_mediaPaths.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            _MediaThumbnailRow(
                              paths: _resolvedPaths.isNotEmpty
                                  ? _resolvedPaths
                                  : _mediaPaths,
                              onRemove: _removeMedia,
                              onTap: _openImageViewer,
                            ),
                          ],

                          const SizedBox(height: 16),

                          // Save & Exit buttons
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: _tryExit,
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.brown[400],
                                    side: BorderSide(
                                        color: Colors.brown[200]!,
                                        width: 1.5),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(12)),
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 13),
                                  ),
                                  child: const Text('Exit'),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                flex: 2,
                                child: ElevatedButton(
                                  onPressed: _isSaving ? null : _save,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor:
                                        const Color(0xFFFFD24B),
                                    foregroundColor:
                                        const Color(0xFF3D2000),
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(12)),
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 13),
                                  ),
                                  child: _isSaving
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Color(0xFF975600),
                                          ),
                                        )
                                      : const Text(
                                          'Save',
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 15),
                                        ),
                                ),
                              ),
                            ],
                          ),

                          Text(
                            '* Label (emoji) is required',
                            style: TextStyle(
                                fontSize: 11, color: Colors.brown[300]),
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
}

// ── Sub-widgets ──────────────────────────────────────────────────────────────

class _ActionButton extends StatelessWidget {
  final String label;
  final bool isFilled;
  final bool isRequired;
  final VoidCallback onTap;

  const _ActionButton({
    required this.label,
    required this.onTap,
    this.isFilled = false,
    this.isRequired = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isFilled
              ? const Color(0xFFFFEA70)
              : const Color(0xFFFFF3C4),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isFilled
                ? const Color(0xFFFFD24B)
                : Colors.brown.withValues(alpha: 0.15),
            width: 1.5,
          ),
        ),
        child: Center(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isFilled
                  ? const Color(0xFF3D2000)
                  : Colors.brown[500],
            ),
          ),
        ),
      ),
    );
  }
}

class _PreviewBanner extends StatelessWidget {
  final String? emoji;
  final String? name;
  final String? word;

  const _PreviewBanner({this.emoji, this.name, this.word});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEFA0),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          if (emoji != null)
            Text(emoji!, style: const TextStyle(fontSize: 26)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (name != null)
                  Text(
                    name!,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Color(0xFF3D2000)),
                  ),
                if (word != null)
                  Text(word!,
                      style: TextStyle(
                          fontSize: 12, color: Colors.brown[400])),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MediaThumbnailRow extends StatelessWidget {
  final List<String> paths;
  final void Function(int) onRemove;
  final void Function(int) onTap;

  const _MediaThumbnailRow({
    required this.paths,
    required this.onRemove,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 80,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: paths.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) => GestureDetector(
          onTap: () => onTap(i),
          child: Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.file(
                  File(paths[i]),
                  width: 80,
                  height: 80,
                  fit: BoxFit.cover,
                ),
              ),
              Positioned(
                top: 2,
                right: 2,
                child: GestureDetector(
                  onTap: () => onRemove(i),
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close,
                        size: 14, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MediaOptionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _MediaOptionTile(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF3C4),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFF975600)),
            const SizedBox(width: 12),
            Text(
              label,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Color(0xFF3D2000),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Full-screen swipeable image viewer ───────────────────────────────────────

class _ImageViewerScreen extends StatefulWidget {
  final List<String> paths;
  final int initialIndex;

  const _ImageViewerScreen({
    required this.paths,
    required this.initialIndex,
  });

  @override
  State<_ImageViewerScreen> createState() => _ImageViewerScreenState();
}

class _ImageViewerScreenState extends State<_ImageViewerScreen> {
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

// ── Dialogs ───────────────────────────────────────────────────────────────────

class _NameInputDialog extends StatefulWidget {
  final String? initialValue;
  const _NameInputDialog({this.initialValue});

  @override
  State<_NameInputDialog> createState() => _NameInputDialogState();
}

class _NameInputDialogState extends State<_NameInputDialog> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFFFFFBEE),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20)),
      title: const Text('Place Name',
          style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF3D2000))),
      content: TextField(
        controller: _ctrl,
        autofocus: true,
        decoration: InputDecoration(
          hintText: 'e.g. My favourite café',
          filled: true,
          fillColor: const Color(0xFFFFF3C4),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel',
              style: TextStyle(color: Colors.brown[400])),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, _ctrl.text),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFFFD24B),
            foregroundColor: const Color(0xFF3D2000),
            elevation: 0,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
          child: const Text('OK'),
        ),
      ],
    );
  }
}

class _DetailsDialog extends StatefulWidget {
  final String? initialValue;
  const _DetailsDialog({this.initialValue});

  @override
  State<_DetailsDialog> createState() => _DetailsDialogState();
}

class _DetailsDialogState extends State<_DetailsDialog> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFFFF9C4),
          borderRadius: BorderRadius.circular(4),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 16,
              offset: const Offset(3, 6),
            ),
          ],
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'My Notes',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF3D2000),
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Icon(Icons.close,
                      color: Colors.brown[300], size: 20),
                ),
              ],
            ),
            const Divider(color: Color(0xFFFFD24B), height: 20),
            TextField(
              controller: _ctrl,
              autofocus: true,
              maxLines: 8,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF3D2000),
                height: 1.6,
              ),
              decoration: const InputDecoration(
                hintText: 'Write your memories here...',
                border: InputBorder.none,
                hintStyle: TextStyle(color: Color(0xFFBBA060)),
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context, _ctrl.text),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFD24B),
                  foregroundColor: const Color(0xFF3D2000),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Done',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UnsavedChangesDialog extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFFFFFBEE),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20)),
      title: const Text('Unsaved Changes',
          style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF3D2000))),
      content: const Text(
        'You have unsaved changes.\nAre you sure you want to exit?',
        style: TextStyle(color: Color(0xFF5C3A00), height: 1.5),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text('Stay',
              style: TextStyle(color: Colors.brown[400])),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFFFD24B),
            foregroundColor: const Color(0xFF3D2000),
            elevation: 0,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
          child: const Text('Exit anyway'),
        ),
      ],
    );
  }
}

class _EmojiInputDialog extends StatefulWidget {
  final void Function(String) onEmojiSelected;
  const _EmojiInputDialog({required this.onEmojiSelected});

  @override
  State<_EmojiInputDialog> createState() => _EmojiInputDialogState();
}

class _EmojiInputDialogState extends State<_EmojiInputDialog> {
  final TextEditingController _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFFFFFBEE),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20)),
      title: const Text('Pick an Emoji',
          style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF3D2000))),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Tap the field below and use your\nkeyboard emoji button to pick one.',
            style: TextStyle(
                fontSize: 13,
                color: Colors.brown[400],
                height: 1.5),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _ctrl,
            autofocus: true,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 32),
            maxLength: 2,
            decoration: InputDecoration(
              counterText: '',
              filled: true,
              fillColor: const Color(0xFFFFF3C4),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              hintText: '😊',
              hintStyle: const TextStyle(fontSize: 32),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel',
              style: TextStyle(color: Colors.brown[400])),
        ),
        ElevatedButton(
          onPressed: () {
            final text = _ctrl.text.trim();
            if (text.isNotEmpty) {
              widget.onEmojiSelected(text);
              Navigator.pop(context);
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFFFD24B),
            foregroundColor: const Color(0xFF3D2000),
            elevation: 0,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
          child: const Text('Use this'),
        ),
      ],
    );
  }
}