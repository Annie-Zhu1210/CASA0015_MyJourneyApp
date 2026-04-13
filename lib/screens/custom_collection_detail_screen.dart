import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import '../models/checkin_location.dart';
import '../models/collections_model.dart';
import '../services/collections_database.dart';
import 'location_detail_screen.dart';

/// Detail screen for a user-created custom collection.
class CustomCollectionDetailScreen extends StatefulWidget {
  final CustomCollection collection;
  final List<CheckInLocation> locations;
  final List<CheckInLocation> ungroupedLocations;
  final VoidCallback onChanged;

  const CustomCollectionDetailScreen({
    super.key,
    required this.collection,
    required this.locations,
    required this.ungroupedLocations,
    required this.onChanged,
  });

  @override
  State<CustomCollectionDetailScreen> createState() =>
      _CustomCollectionDetailScreenState();
}

class _CustomCollectionDetailScreenState
    extends State<CustomCollectionDetailScreen> {
  late List<CheckInLocation> _locations;
  late CustomCollection _collection;
  bool _removeMode = false;
  final Set<String> _selectedForRemoval = {};
  final Map<String, String> _places = {};

  @override
  void initState() {
    super.initState();
    _locations = List.from(widget.locations);
    _collection = widget.collection;
    _geocodeAll(_locations);
  }

  // ── Geocoding ─────────────────────────────────────────────────────────────

  Future<void> _geocodeAll(List<CheckInLocation> locs) async {
    for (final loc in locs) {
      if (!mounted) return;
      if (_places.containsKey(loc.id)) continue;
      final place = await _resolvePlace(loc);
      if (mounted) setState(() => _places[loc.id] = place);
    }
  }

  static Future<String> _resolvePlace(CheckInLocation loc) async {
    try {
      final placemarks = await placemarkFromCoordinates(
        loc.latitude,
        loc.longitude,
        localeIdentifier: 'en_US',
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
    return '${loc.latitude.toStringAsFixed(4)}, '
        '${loc.longitude.toStringAsFixed(4)}';
  }


  // ── Reorder ───────────────────────────────────────────────────────────────

  Future<void> _onReorder(int oldIndex, int newIndex) async {
    setState(() {
      if (newIndex > oldIndex) newIndex--;
      final item = _locations.removeAt(oldIndex);
      _locations.insert(newIndex, item);
    });
    final updatedIds = _locations.map((l) => l.id).toList();
    _collection = _collection.copyWith(locationIds: updatedIds);
    await CollectionsDatabase.update(_collection);
    widget.onChanged();
  }

  // ── Add locations ─────────────────────────────────────────────────────────

  Future<void> _openAddSheet() async {
    if (widget.ungroupedLocations.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No ungrouped locations to add.'),
          backgroundColor: Color(0xFF975600),
        ),
      );
      return;
    }

    await _geocodeAll(widget.ungroupedLocations);

    final selected = await showModalBottomSheet<List<String>>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _AddLocationsSheet(
        ungrouped: widget.ungroupedLocations,
        places: _places,
      ),
    );

    if (selected == null || selected.isEmpty) return;

    final toAdd = widget.ungroupedLocations
        .where((l) => selected.contains(l.id))
        .toList();

    setState(() => _locations = [..._locations, ...toAdd]);
    final updatedIds = _locations.map((l) => l.id).toList();
    _collection = _collection.copyWith(locationIds: updatedIds);
    await CollectionsDatabase.update(_collection);
    widget.onChanged();
  }

  // ── Remove locations ──────────────────────────────────────────────────────

  void _toggleRemoveMode() {
    setState(() {
      _removeMode = !_removeMode;
      _selectedForRemoval.clear();
    });
  }

  void _toggleSelect(String id) {
    setState(() {
      _selectedForRemoval.contains(id)
          ? _selectedForRemoval.remove(id)
          : _selectedForRemoval.add(id);
    });
  }

  Future<void> _confirmRemove() async {
    if (_selectedForRemoval.isEmpty) return;
    setState(() {
      _locations = _locations
          .where((l) => !_selectedForRemoval.contains(l.id))
          .toList();
      _removeMode = false;
      _selectedForRemoval.clear();
    });
    final updatedIds = _locations.map((l) => l.id).toList();
    _collection = _collection.copyWith(locationIds: updatedIds);
    await CollectionsDatabase.update(_collection);
    widget.onChanged();
  }

  // ── Open location detail ──────────────────────────────────────────────────

  void _openDetail(CheckInLocation checkIn) {
    if (_removeMode) {
      _toggleSelect(checkIn.id);
      return;
    }
    Navigator.push(
      context,
      _slideRightRoute(
        LocationDetailScreen(
          checkIn: checkIn,
          onChanged: () {
            widget.onChanged();
            Navigator.pop(context);
          },
        ),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F0),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                height: 1.5,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFFFFD227).withOpacity(0.8),
                      const Color(0xFFFFD227).withOpacity(0.0),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 150),
                style: TextStyle(
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                  color: _removeMode
                      ? Colors.red.shade400
                      : const Color(0xFF3E1F00).withOpacity(0.35),
                ),
                child: Text(_removeMode
                    ? 'Tap locations to select for removal'
                    : 'Hold & drag to reorder'),
              ),
            ),
            Expanded(
              child: _locations.isEmpty
                  ? _buildEmptyState()
                  : _removeMode
                      ? _buildSelectableList()
                      : _buildReorderableList(),
            ),
            _buildBottomBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 10, 20, 12),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context, _locations),
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
            color: Color(0xFF975600), size: 20),
            tooltip: 'Back',
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _collection.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF3E1F00),
                    letterSpacing: -0.3,
                  ),
                ),
                Text(
                  '${_locations.length} location${_locations.length == 1 ? '' : 's'}',
                  style: TextStyle(
                    fontSize: 12,
                    color: const Color(0xFF3E1F00).withOpacity(0.45),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReorderableList() {
    return ReorderableListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      onReorder: _onReorder,
      proxyDecorator: _proxyDecorator,
      itemCount: _locations.length,
      itemBuilder: (context, index) {
        final loc = _locations[index];
        return _LocationCard(
          key: ValueKey(loc.id),
          checkIn: loc,
          place: _places[loc.id],
          onTap: () => _openDetail(loc),
          isSelected: false,
          showDragHandle: true,
        );
      },
    );
  }

  Widget _buildSelectableList() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      itemCount: _locations.length,
      itemBuilder: (context, index) {
        final loc = _locations[index];
        return _LocationCard(
          key: ValueKey(loc.id),
          checkIn: loc,
          place: _places[loc.id],
          onTap: () => _toggleSelect(loc.id),
          isSelected: _selectedForRemoval.contains(loc.id),
          showDragHandle: false,
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.folder_open_rounded,
              size: 48, color: const Color(0xFFB87000).withOpacity(0.3)),
          const SizedBox(height: 12),
          Text(
            'This collection is empty',
            style: TextStyle(
              fontSize: 15,
              color: const Color(0xFF3E1F00).withOpacity(0.4),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Tap + above to add locations',
            style: TextStyle(
              fontSize: 13,
              color: const Color(0xFF3E1F00).withOpacity(0.3),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    if (_removeMode) {
      return Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF8F0),
          border: Border(
            top: BorderSide(
                color: const Color(0xFFFFD227).withOpacity(0.4), width: 1),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _toggleRemoveMode,
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF975600),
                  side: const BorderSide(color: Color(0xFFFFD227), width: 1.5),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('Cancel'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: ElevatedButton(
                onPressed:
                    _selectedForRemoval.isEmpty ? null : _confirmRemove,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red[400],
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey[200],
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: Text(
                  _selectedForRemoval.isEmpty
                      ? 'Remove'
                      : 'Remove (${_selectedForRemoval.length})',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8F0),
        border: Border(
          top: BorderSide(
              color: const Color(0xFFFFD227).withOpacity(0.4), width: 1),
        ),
      ),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: _locations.isEmpty ? null : _toggleRemoveMode,
          icon: const Icon(Icons.remove_circle_outline_rounded, size: 18),
          label: const Text('Remove Locations'),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.red[400],
            side: BorderSide(color: Colors.red[200]!, width: 1.5),
            disabledForegroundColor: Colors.grey[400],
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      ),
    );
  }

  Widget _proxyDecorator(
      Widget child, int index, Animation<double> animation) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) => Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(16),
        shadowColor: const Color(0xFFB87000).withOpacity(0.3),
        child: child,
      ),
      child: child,
    );
  }
}

// ── Add locations bottom sheet ────────────────────────────────────────────────

class _AddLocationsSheet extends StatefulWidget {
  final List<CheckInLocation> ungrouped;
  final Map<String, String> places;

  const _AddLocationsSheet({
    required this.ungrouped,
    required this.places,
  });

  @override
  State<_AddLocationsSheet> createState() => _AddLocationsSheetState();
}

class _AddLocationsSheetState extends State<_AddLocationsSheet> {
  final Set<String> _selected = {};

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFFFFBEE),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.brown[200],
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Add to Collection',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: Color(0xFF3D2000),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Select locations to add',
            style: TextStyle(fontSize: 13, color: Colors.brown[400]),
          ),
          const SizedBox(height: 12),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.45,
            ),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: widget.ungrouped.length,
              itemBuilder: (_, i) {
                final loc = widget.ungrouped[i];
                final isSelected = _selected.contains(loc.id);
                final place = widget.places[loc.id];
                return GestureDetector(
                  onTap: () => setState(() {
                    isSelected
                        ? _selected.remove(loc.id)
                        : _selected.add(loc.id);
                  }),
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    height: 62,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFFFFD227).withOpacity(0.2)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFFFFD227)
                            : Colors.transparent,
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFB87000).withOpacity(0.06),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 80,
                          height: 62,
                          decoration: const BoxDecoration(
                            color: Color(0xFFFFD227),
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(12),
                              bottomLeft: Radius.circular(12),
                            ),
                          ),
                          child: Center(
                            child: Text(
                              loc.displayLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF3E1F00)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                loc.name?.isNotEmpty == true
                                    ? loc.name!
                                    : 'Unnamed location',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: loc.name?.isNotEmpty == true
                                      ? const Color(0xFF3E1F00)
                                      : const Color(0xFF3E1F00)
                                          .withOpacity(0.4),
                                ),
                              ),
                              if (place != null)
                                Text(
                                  place,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: const Color(0xFF3E1F00)
                                        .withOpacity(0.45),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        if (isSelected)
                          const Padding(
                            padding: EdgeInsets.only(right: 14),
                            child: Icon(Icons.check_circle_rounded,
                                color: Color(0xFF975600), size: 20),
                          )
                        else
                          Padding(
                            padding: const EdgeInsets.only(right: 14),
                            child: Icon(Icons.circle_outlined,
                                color:
                                    const Color(0xFF3E1F00).withOpacity(0.2),
                                size: 20),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _selected.isEmpty
                  ? null
                  : () => Navigator.pop(context, _selected.toList()),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFD24B),
                foregroundColor: const Color(0xFF3D2000),
                disabledBackgroundColor: Colors.grey[200],
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: Text(
                _selected.isEmpty
                    ? 'Add to Collection'
                    : 'Add ${_selected.length} location${_selected.length == 1 ? '' : 's'}',
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ── Location card ─────────────────────────────────────────────────────────────

class _LocationCard extends StatelessWidget {
  final CheckInLocation checkIn;
  final String? place;
  final VoidCallback onTap;
  final bool isSelected;
  final bool showDragHandle;

  const _LocationCard({
    super.key,
    required this.checkIn,
    required this.place,
    required this.onTap,
    required this.isSelected,
    required this.showDragHandle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 70,
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFFFFD227).withOpacity(0.15)
                : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color:
                  isSelected ? const Color(0xFFFFD227) : Colors.transparent,
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFB87000).withOpacity(0.08),
                blurRadius: 12,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 90,
                height: 70,
                decoration: const BoxDecoration(
                  color: Color(0xFFFFD227),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(16),
                    bottomLeft: Radius.circular(16),
                  ),
                ),
                child: Center(
                  child: Text(
                    checkIn.displayLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF3E1F00),
                    ),
                  ),
                ),
              ),
              Container(
                  width: 3,
                  height: 70,
                  color: const Color(0xFFFFD227).withOpacity(0.6)),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        checkIn.name?.isNotEmpty == true
                            ? checkIn.name!
                            : 'Unnamed location',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: checkIn.name?.isNotEmpty == true
                              ? const Color(0xFF3E1F00)
                              : const Color(0xFF3E1F00).withOpacity(0.35),
                        ),
                      ),
                      const SizedBox(height: 3),
                      place == null
                          ? SizedBox(
                              height: 11,
                              width: 80,
                              child: LinearProgressIndicator(
                                backgroundColor: const Color(0xFFFFD6E0)
                                    .withOpacity(0.4),
                                color: const Color(0xFFFFD6E0),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            )
                          : Text(
                              place!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                color: const Color(0xFF3E1F00)
                                    .withOpacity(0.45),
                              ),
                            ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 14),
                child: isSelected
                    ? const Icon(Icons.check_circle_rounded,
                        color: Color(0xFF975600), size: 20)
                    : showDragHandle
                        ? Icon(Icons.drag_handle_rounded,
                            color:
                                const Color(0xFFB87000).withOpacity(0.35),
                            size: 20)
                        : Icon(Icons.remove_circle_outline_rounded,
                            color: Colors.red[300], size: 20),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Slide-from-right page route ───────────────────────────────────────────────

PageRouteBuilder<T> _slideRightRoute<T>(Widget page) {
  return PageRouteBuilder<T>(
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      const begin = Offset(1.0, 0.0);
      const end = Offset.zero;
      const curve = Curves.easeInOutCubic;
      final tween =
          Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
      final secondaryTween =
          Tween(begin: Offset.zero, end: const Offset(-0.3, 0.0))
              .chain(CurveTween(curve: curve));
      return SlideTransition(
        position: secondaryAnimation.drive(secondaryTween),
        child: SlideTransition(
          position: animation.drive(tween),
          child: child,
        ),
      );
    },
    transitionDuration: const Duration(milliseconds: 320),
    reverseTransitionDuration: const Duration(milliseconds: 280),
  );
}