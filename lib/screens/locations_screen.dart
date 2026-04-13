import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geocoding/geocoding.dart';
import 'package:uuid/uuid.dart';
import '../models/checkin_location.dart';
import '../models/collections_model.dart';
import '../constants/checkin_labels.dart';
import 'location_detail_screen.dart';
import 'collection_detail_screen.dart';
import 'custom_collection_detail_screen.dart';
import '../services/collections_database.dart';
import '../services/noticeboard_service.dart';

// ── Collection tab enum ───────────────────────────────────────────────────────

enum _CollectionTab { city, label, myCollections, fromFriends }

// ── Main screen ───────────────────────────────────────────────────────────────

class LocationsScreen extends StatefulWidget {
  final List<CheckInLocation> checkIns;
  final VoidCallback onChanged;

  const LocationsScreen({
    super.key,
    this.checkIns = const [],
    required this.onChanged,
  });

  @override
  State<LocationsScreen> createState() => _LocationsScreenState();
}

class _LocationsScreenState extends State<LocationsScreen> {
  _CollectionTab _activeTab = _CollectionTab.city;
  List<CustomCollection> _customCollections = [];
  bool _collectionsLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadCollections();
  }

  @override
  void didUpdateWidget(LocationsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    _loadCollections();
  }

  Future<void> _loadCollections() async {
    final collections = await CollectionsDatabase.loadAll();
    if (mounted) {
      setState(() {
        _customCollections = collections;
        _collectionsLoaded = true;
      });
    }
  }

  void _switchTab(_CollectionTab tab) {
    if (_activeTab == tab) return;
    setState(() => _activeTab = tab);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFFFF8F0),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ───────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Row(
                children: [
                  const Text(
                    'My Locations',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF3E1F00),
                      letterSpacing: -0.5,
                    ),
                  ),
                  const Spacer(),
                  // ── Count badge ─────────────────────────────────────────
                  if (widget.checkIns.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFD227),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${widget.checkIns.length}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF3E1F00),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // ── Tab selector ─────────────────────────────────────────────
            _buildTabSelector(),

            // ── Divider ──────────────────────────────────────────────────
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

            const SizedBox(height: 8),

            // ── Content ──────────────────────────────────────────────────
            Expanded(
              child:
                  widget.checkIns.isEmpty &&
                      _activeTab != _CollectionTab.myCollections &&
                      _activeTab != _CollectionTab.fromFriends
                  ? _buildEmptyState()
                  : _buildActiveView(),
            ),
          ],
        ),
      ),
    );
  }

  // ── Tab selector ──────────────────────────────────────────────────────────

  Widget _buildTabSelector() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _TabOption(
              label: 'City',
              isActive: _activeTab == _CollectionTab.city,
              onTap: () => _switchTab(_CollectionTab.city),
            ),
            const SizedBox(width: 16),
            _TabOption(
              label: 'Label',
              isActive: _activeTab == _CollectionTab.label,
              onTap: () => _switchTab(_CollectionTab.label),
            ),
            const SizedBox(width: 16),
            _TabOption(
              label: 'My Collections',
              isActive: _activeTab == _CollectionTab.myCollections,
              onTap: () => _switchTab(_CollectionTab.myCollections),
            ),
            const SizedBox(width: 16),
            _TabOption(
              label: 'From Friends',
              isActive: _activeTab == _CollectionTab.fromFriends,
              onTap: () => _switchTab(_CollectionTab.fromFriends),
            ),
          ],
        ),
      ),
    );
  }

  // ── Active view router ────────────────────────────────────────────────────

  Widget _buildActiveView() {
    switch (_activeTab) {
      case _CollectionTab.city:
        return _CityView(
          checkIns: widget.checkIns,
          onChanged: widget.onChanged,
        );
      case _CollectionTab.label:
        return _LabelView(
          checkIns: widget.checkIns,
          onChanged: widget.onChanged,
        );
      case _CollectionTab.myCollections:
        if (!_collectionsLoaded) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFFFFD227)),
          );
        }
        return _MyCollectionsView(
          checkIns: widget.checkIns,
          collections: _customCollections,
          onChanged: () {
            widget.onChanged();
            _loadCollections();
          },
          onCollectionsChanged: _loadCollections,
        );
      case _CollectionTab.fromFriends:
        return const _FromFriendsView();
    }
  }

  // ── Empty state ───────────────────────────────────────────────────────────

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: const Color(0xFFFFD227).withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.add_location_alt_outlined,
              size: 36,
              color: Color(0xFFB87000),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'No locations yet',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: Color(0xFF3E1F00),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Long-press on the map to\nadd your first check-in',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: const Color(0xFF3E1F00).withOpacity(0.5),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Tab option widget ─────────────────────────────────────────────────────────

class _TabOption extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _TabOption({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedDefaultTextStyle(
        duration: const Duration(milliseconds: 150),
        style: TextStyle(
          fontSize: 13,
          fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
          color: isActive
              ? const Color(0xFF975600)
              : const Color(0xFF3E1F00).withOpacity(0.45),
          decoration: isActive ? TextDecoration.underline : TextDecoration.none,
          decorationColor: const Color(0xFFFFD227),
          decorationThickness: 2,
        ),
        child: Text(label),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CITY VIEW
// ─────────────────────────────────────────────────────────────────────────────

class _CityView extends StatefulWidget {
  final List<CheckInLocation> checkIns;
  final VoidCallback onChanged;

  const _CityView({required this.checkIns, required this.onChanged});

  @override
  State<_CityView> createState() => _CityViewState();
}

class _CityViewState extends State<_CityView> {
  Map<String, List<CheckInLocation>> _cityMap = {};
  List<String> _cityKeys = [];
  final Map<String, String> _cityDisplayNames = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _buildCityMap();
  }

  @override
  void didUpdateWidget(_CityView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.checkIns != widget.checkIns) _buildCityMap();
  }

  Future<void> _buildCityMap() async {
    setState(() => _loading = true);

    final Map<String, List<CheckInLocation>> cityMap = {};
    final Map<String, String> displayNames = {};

    for (final c in widget.checkIns) {
      String cityKey;
      String displayName;
      try {
        final placemarks = await placemarkFromCoordinates(
          c.latitude,
          c.longitude,
          localeIdentifier: 'en_US',
        );
        if (placemarks.isNotEmpty) {
          final p = placemarks.first;
          final city =
              (p.locality?.isNotEmpty == true ? p.locality! : null) ??
              (p.administrativeArea?.isNotEmpty == true
                  ? p.administrativeArea!
                  : null) ??
              'Unknown';
          final country = p.country?.isNotEmpty == true ? p.country! : '';
          cityKey = '$city|$country';
          displayName = country.isNotEmpty ? '$city, $country' : city;
        } else {
          cityKey = 'unknown';
          displayName = 'Unknown';
        }
      } catch (_) {
        cityKey = 'unknown';
        displayName = 'Unknown';
      }

      cityMap.putIfAbsent(cityKey, () => []).add(c);
      displayNames[cityKey] = displayName;
    }

    for (final key in cityMap.keys) {
      cityMap[key]!.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }

    final cityKeys = cityMap.keys.toList()
      ..sort((a, b) {
        final latestA = cityMap[a]!.first.createdAt;
        final latestB = cityMap[b]!.first.createdAt;
        return latestB.compareTo(latestA);
      });

    if (mounted) {
      setState(() {
        _cityMap = cityMap;
        _cityKeys = cityKeys;
        _cityDisplayNames.addAll(displayNames);
        _loading = false;
      });
    }
  }

  void _openCollection(String cityKey) async {
    final locations = List<CheckInLocation>.from(_cityMap[cityKey]!);
    final result = await Navigator.push<List<CheckInLocation>>(
      context,
      _slideRightRoute<List<CheckInLocation>>(
        CollectionDetailScreen(
          title: _cityDisplayNames[cityKey] ?? cityKey,
          subtitle:
              '${locations.length} location${locations.length == 1 ? '' : 's'}',
          locations: locations,
          onChanged: widget.onChanged,
        ),
      ),
    );
    if (result != null && mounted) {
      setState(() => _cityMap[cityKey] = result);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFFFD227)),
      );
    }

    if (_cityKeys.isEmpty) {
      return Center(
        child: Text(
          'No city collections yet',
          style: TextStyle(
            fontSize: 15,
            color: const Color(0xFF3E1F00).withOpacity(0.4),
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
      itemCount: _cityKeys.length,
      itemBuilder: (context, index) {
        final key = _cityKeys[index];
        final locs = _cityMap[key]!;
        return _CollectionCard(
          title: _cityDisplayNames[key] ?? key,
          count: locs.length,
          previewEmojis: locs.take(3).map((l) => l.emoji).toList(),
          onTap: () => _openCollection(key),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LABEL VIEW
// ─────────────────────────────────────────────────────────────────────────────

class _LabelView extends StatefulWidget {
  final List<CheckInLocation> checkIns;
  final VoidCallback onChanged;

  const _LabelView({required this.checkIns, required this.onChanged});

  @override
  State<_LabelView> createState() => _LabelViewState();
}

class _LabelViewState extends State<_LabelView> {
  List<String> _labelKeys = [];
  Map<String, List<CheckInLocation>> _labelMap = {};
  final Map<String, String> _labelTitles = {};

  static const String _othersKey = '__others__';

  @override
  void initState() {
    super.initState();
    _buildLabelMap();
  }

  @override
  void didUpdateWidget(_LabelView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.checkIns != widget.checkIns) _buildLabelMap();
  }

  void _buildLabelMap() {
    final presetWords = kPresetLabels.map((l) => l.word).toSet();
    final Map<String, List<CheckInLocation>> labelMap = {};

    for (final c in widget.checkIns) {
      final word = c.labelWord;
      final String key;
      if (word != null && presetWords.contains(word)) {
        key = word;
      } else {
        key = _othersKey;
      }
      labelMap.putIfAbsent(key, () => []).add(c);
    }

    for (final key in labelMap.keys) {
      labelMap[key]!.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }

    final orderedKeys = <String>[];
    final usedPresets = kPresetLabels
        .map((l) => l.word)
        .where((w) => labelMap.containsKey(w))
        .toList();
    usedPresets.sort((a, b) {
      final latestA = labelMap[a]!.first.createdAt;
      final latestB = labelMap[b]!.first.createdAt;
      return latestB.compareTo(latestA);
    });
    orderedKeys.addAll(usedPresets);
    if (labelMap.containsKey(_othersKey)) orderedKeys.add(_othersKey);

    final Map<String, String> titles = {};
    for (final preset in kPresetLabels) {
      titles[preset.word] = '${preset.emoji} ${preset.word}';
    }
    titles[_othersKey] = '🗂️ Others';

    setState(() {
      _labelMap = labelMap;
      _labelKeys = orderedKeys;
      _labelTitles.addAll(titles);
    });
  }

  void _openCollection(String labelKey) async {
    final locations = List<CheckInLocation>.from(_labelMap[labelKey]!);
    final result = await Navigator.push<List<CheckInLocation>>(
      context,
      _slideRightRoute<List<CheckInLocation>>(
        CollectionDetailScreen(
          title: _labelTitles[labelKey] ?? labelKey,
          subtitle:
              '${locations.length} location${locations.length == 1 ? '' : 's'}',
          locations: locations,
          onChanged: widget.onChanged,
        ),
      ),
    );
    if (result != null && mounted) {
      setState(() => _labelMap[labelKey] = result);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_labelKeys.isEmpty) {
      return Center(
        child: Text(
          'No label collections yet',
          style: TextStyle(
            fontSize: 15,
            color: const Color(0xFF3E1F00).withOpacity(0.4),
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
      itemCount: _labelKeys.length,
      itemBuilder: (context, index) {
        final key = _labelKeys[index];
        final locs = _labelMap[key]!;
        return _CollectionCard(
          title: _labelTitles[key] ?? key,
          count: locs.length,
          previewEmojis: locs.take(3).map((l) => l.emoji).toList(),
          onTap: () => _openCollection(key),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MY COLLECTIONS VIEW
// ─────────────────────────────────────────────────────────────────────────────

class _MyCollectionsView extends StatefulWidget {
  final List<CheckInLocation> checkIns;
  final List<CustomCollection> collections;
  final VoidCallback onChanged;
  final VoidCallback onCollectionsChanged;

  const _MyCollectionsView({
    required this.checkIns,
    required this.collections,
    required this.onChanged,
    required this.onCollectionsChanged,
  });

  @override
  State<_MyCollectionsView> createState() => _MyCollectionsViewState();
}

class _MyCollectionsViewState extends State<_MyCollectionsView> {
  late List<CustomCollection> _collections;
  final Map<String, String> _places = {};

  @override
  void initState() {
    super.initState();
    _collections = List.from(widget.collections);
    _geocodeUngrouped();
  }

  @override
  void didUpdateWidget(_MyCollectionsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.collections != widget.collections) {
      setState(() => _collections = List.from(widget.collections));
    }
    _geocodeUngrouped();
  }

  Future<void> _geocodeUngrouped() async {
    for (final loc in _ungroupedLocations) {
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

  List<CheckInLocation> get _ungroupedLocations {
    final allAssigned = _collections.expand((c) => c.locationIds).toSet();
    return widget.checkIns.where((l) => !allAssigned.contains(l.id)).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  List<CheckInLocation> _locationsForCollection(CustomCollection collection) {
    final idOrder = collection.locationIds;
    final byId = {for (final l in widget.checkIns) l.id: l};
    return idOrder.map((id) => byId[id]).whereType<CheckInLocation>().toList();
  }

  Future<void> _showCreateDialog() async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => const _CreateCollectionDialog(),
    );
    if (name == null || name.trim().isEmpty) return;

    final newCollection = CustomCollection(
      id: const Uuid().v4(),
      name: name.trim(),
      locationIds: [],
      createdAt: DateTime.now(),
      sortOrder: 0,
    );

    final updated = _collections
        .map((c) => c.copyWith(sortOrder: c.sortOrder + 1))
        .toList();
    for (final c in updated) {
      await CollectionsDatabase.update(c);
    }
    await CollectionsDatabase.insert(newCollection);
    widget.onCollectionsChanged();
  }

  Future<void> _onReorder(int oldIndex, int newIndex) async {
    setState(() {
      if (newIndex > oldIndex) newIndex--;
      final item = _collections.removeAt(oldIndex);
      _collections.insert(newIndex, item);
    });
    await CollectionsDatabase.updateOrder(_collections);
    widget.onCollectionsChanged();
  }

  void _openCollection(CustomCollection collection) {
    final locs = _locationsForCollection(collection);
    Navigator.push(
      context,
      _slideRightRoute(
        CustomCollectionDetailScreen(
          collection: collection,
          locations: locs,
          ungroupedLocations: _ungroupedLocations,
          onChanged: () {
            widget.onChanged();
            widget.onCollectionsChanged();
          },
        ),
      ),
    ).then((_) => widget.onCollectionsChanged());
  }

  Future<void> _dropIntoCollection(
    CheckInLocation loc,
    String collectionId,
  ) async {
    final target = _collections.firstWhere((c) => c.id == collectionId);
    final updatedIds = [...target.locationIds, loc.id];
    final updated = target.copyWith(locationIds: updatedIds);
    await CollectionsDatabase.update(updated);
    widget.onCollectionsChanged();
  }

  void _openLocation(CheckInLocation checkIn) {
    Navigator.push(
      context,
      _slideRightRoute(
        LocationDetailScreen(checkIn: checkIn, onChanged: widget.onChanged),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ungrouped = _ungroupedLocations;

    return CustomScrollView(
      slivers: [
        if (_collections.isNotEmpty)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            sliver: SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Text(
                      'Collections',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF975600).withOpacity(0.8),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'Hold & drag to reorder',
                      style: TextStyle(
                        fontSize: 11,
                        color: const Color(0xFF3E1F00).withOpacity(0.3),
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

        if (_collections.isNotEmpty)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            sliver: SliverReorderableList(
              itemCount: _collections.length,
              onReorder: _onReorder,
              proxyDecorator: _proxyDecorator,
              itemBuilder: (context, index) {
                final collection = _collections[index];
                final locs = _locationsForCollection(collection);
                return ReorderableDragStartListener(
                  key: ValueKey(collection.id),
                  index: index,
                  child: DragTarget<CheckInLocation>(
                    onWillAcceptWithDetails: (details) =>
                        !collection.locationIds.contains(details.data.id),
                    onAcceptWithDetails: (details) =>
                        _dropIntoCollection(details.data, collection.id),
                    builder: (context, candidateData, rejectedData) {
                      final isHovered = candidateData.isNotEmpty;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: isHovered
                                ? const Color(0xFF975600)
                                : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: _CollectionCard(
                          title: collection.name,
                          count: locs.length,
                          previewEmojis: locs
                              .take(3)
                              .map((l) => l.emoji)
                              .toList(),
                          onTap: () => _openCollection(collection),
                          showDragHandle: true,
                          isDropTarget: isHovered,
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),

        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          sliver: SliverToBoxAdapter(
            child: GestureDetector(
              onTap: _showCreateDialog,
              child: Container(
                height: 52,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFD227).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: const Color(0xFFFFD227).withOpacity(0.5),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.add_rounded,
                      color: const Color(0xFF975600).withOpacity(0.7),
                      size: 20,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'New Collection',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF975600).withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        if (ungrouped.isNotEmpty)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            sliver: SliverToBoxAdapter(
              child: Text(
                'Ungrouped',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF975600).withOpacity(0.8),
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),

        if (ungrouped.isNotEmpty)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => _UngroupedLocationCard(
                  checkIn: ungrouped[index],
                  place: _places[ungrouped[index].id],
                  onTap: () => _openLocation(ungrouped[index]),
                ),
                childCount: ungrouped.length,
              ),
            ),
          ),

        if (ungrouped.isEmpty && widget.checkIns.isEmpty)
          SliverFillRemaining(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFD227).withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.add_location_alt_outlined,
                      size: 36,
                      color: Color(0xFFB87000),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No locations yet',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF3E1F00),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Long-press on the map to\nadd your first check-in',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: const Color(0xFF3E1F00).withOpacity(0.5),
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _proxyDecorator(Widget child, int index, Animation<double> animation) {
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

// ─────────────────────────────────────────────────────────────────────────────
// SHARED WIDGETS
// ─────────────────────────────────────────────────────────────────────────────

class _CollectionCard extends StatelessWidget {
  final String title;
  final int count;
  final List<String> previewEmojis;
  final VoidCallback onTap;
  final bool showDragHandle;
  final bool isDropTarget;

  const _CollectionCard({
    required this.title,
    required this.count,
    required this.previewEmojis,
    required this.onTap,
    this.showDragHandle = false,
    this.isDropTarget = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 70,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
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
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 90,
                height: 70,
                decoration: BoxDecoration(
                  color: isDropTarget
                      ? const Color(0xFFB84400)
                      : const Color(0xFFE05A00),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    bottomLeft: Radius.circular(16),
                  ),
                ),
                child: Center(
                  child: isDropTarget
                      ? const Icon(
                          Icons.add_rounded,
                          color: Color(0xFF975600),
                          size: 28,
                        )
                      : previewEmojis.isEmpty
                      ? const Icon(
                          Icons.folder_rounded,
                          color: Color(0xFF975600),
                          size: 28,
                        )
                      : Text(
                          previewEmojis.take(3).join(' '),
                          style: const TextStyle(fontSize: 18),
                          textAlign: TextAlign.center,
                        ),
                ),
              ),
              Container(
                width: 3,
                height: 70,
                color: const Color(0xFFE05A00).withOpacity(0.4),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF3E1F00),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '$count location${count == 1 ? '' : 's'}',
                        style: TextStyle(
                          fontSize: 11,
                          color: const Color(0xFF3E1F00).withOpacity(0.45),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 14),
                child: showDragHandle
                    ? Icon(
                        Icons.drag_handle_rounded,
                        color: const Color(0xFFB87000).withOpacity(0.35),
                        size: 20,
                      )
                    : Icon(
                        Icons.chevron_right_rounded,
                        color: const Color(0xFFB87000).withOpacity(0.4),
                        size: 20,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UngroupedLocationCard extends StatelessWidget {
  final CheckInLocation checkIn;
  final String? place;
  final VoidCallback onTap;

  const _UngroupedLocationCard({
    required this.checkIn,
    required this.place,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: LongPressDraggable<CheckInLocation>(
        data: checkIn,
        feedback: Material(
          elevation: 8,
          borderRadius: BorderRadius.circular(16),
          shadowColor: const Color(0xFFB87000).withOpacity(0.3),
          child: SizedBox(
            width: MediaQuery.of(context).size.width - 32,
            child: _buildCard(isDragging: false),
          ),
        ),
        childWhenDragging: Opacity(
          opacity: 0.4,
          child: _buildCard(isDragging: true),
        ),
        child: GestureDetector(
          onTap: onTap,
          child: _buildCard(isDragging: false),
        ),
      ),
    );
  }

  Widget _buildCard({required bool isDragging}) {
    return Container(
      height: 70,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
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
            color: const Color(0xFFFFD227).withOpacity(0.6),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
                            backgroundColor: const Color(
                              0xFFFFD6E0,
                            ).withOpacity(0.4),
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
                            color: const Color(0xFF3E1F00).withOpacity(0.4),
                          ),
                        ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: Icon(
              Icons.open_with_rounded,
              color: const Color(0xFFB87000).withOpacity(0.3),
              size: 18,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CREATE COLLECTION DIALOG
// ─────────────────────────────────────────────────────────────────────────────

class _CreateCollectionDialog extends StatefulWidget {
  const _CreateCollectionDialog();

  @override
  State<_CreateCollectionDialog> createState() =>
      _CreateCollectionDialogState();
}

class _CreateCollectionDialogState extends State<_CreateCollectionDialog> {
  final TextEditingController _ctrl = TextEditingController();
  static const int _maxLength = 30;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFFFFFBEE),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text(
        'New Collection',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Color(0xFF3D2000),
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Give your collection a name or emoji',
            style: TextStyle(fontSize: 13, color: Colors.brown[400]),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _ctrl,
            autofocus: true,
            maxLength: _maxLength,
            inputFormatters: [LengthLimitingTextInputFormatter(_maxLength)],
            style: const TextStyle(fontSize: 16, color: Color(0xFF3D2000)),
            decoration: InputDecoration(
              hintText: 'e.g. Tokyo Trip 🗼 or ❤️ Favourites',
              hintStyle: TextStyle(fontSize: 13, color: Colors.brown[300]),
              filled: true,
              fillColor: const Color(0xFFFFF3C4),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              counterStyle: TextStyle(fontSize: 11, color: Colors.brown[300]),
            ),
            onSubmitted: (_) {
              final text = _ctrl.text.trim();
              if (text.isNotEmpty) Navigator.pop(context, text);
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel', style: TextStyle(color: Colors.brown[400])),
        ),
        ElevatedButton(
          onPressed: () {
            final text = _ctrl.text.trim();
            if (text.isNotEmpty) Navigator.pop(context, text);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFFFD24B),
            foregroundColor: const Color(0xFF3D2000),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: const Text(
            'Create',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FROM FRIENDS VIEW
// ─────────────────────────────────────────────────────────────────────────────

class _FromFriendsView extends StatefulWidget {
  const _FromFriendsView();

  @override
  State<_FromFriendsView> createState() => _FromFriendsViewState();
}

class _FromFriendsViewState extends State<_FromFriendsView> {
  List<NoticeboardPost> _imported = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final items = await NoticeboardService.fetchImported();
    if (mounted)
      setState(() {
        _imported = items;
        _loading = false;
      });
  }

  String _formatDate(DateTime dt) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFFFD227)),
      );
    }

    if (_imported.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: const Color(0xFFFFD227).withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.download_outlined,
                size: 36,
                color: Color(0xFFB87000),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'No imported locations yet',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: Color(0xFF3E1F00),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Import locations from the\nnoticeboard on the World screen.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: const Color(0xFF3E1F00).withOpacity(0.5),
                height: 1.5,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: const Color(0xFFFFD227),
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
        itemCount: _imported.length,
        itemBuilder: (context, index) {
          final post = _imported[index];
          return Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: GestureDetector(
                onTap: () => showModalBottomSheet(
                  context: context,
                  backgroundColor: Colors.transparent,
                  isScrollControlled: true,
                  builder: (_) => _FromFriendsDetailSheet(post: post),
                ),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
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
                  // ── Emoji pill ────────────────────────────────────
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
                        post.emoji,
                        style: const TextStyle(fontSize: 26),
                      ),
                    ),
                  ),
                  Container(
                    width: 3,
                    height: 70,
                    color: const Color(0xFFFFD227).withOpacity(0.6),
                  ),
                  // ── Content ───────────────────────────────────────
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            post.locationName?.isNotEmpty == true
                                ? post.locationName!
                                : post.displayLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF3E1F00),
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            post.city?.isNotEmpty == true
                                ? post.city!
                                : 'Unknown location',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              color: const Color(0xFF3E1F00).withOpacity(0.45),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // ── Date + from badge ─────────────────────────────
                  Padding(
                    padding: const EdgeInsets.only(right: 14),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE05A00).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '@${post.username}',
                            style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFFE05A00),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatDate(post.sharedAt),
                          style: TextStyle(
                            fontSize: 10,
                            color: const Color(0xFF3E1F00).withOpacity(0.35),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ));
        },
      ),
    );
  }
}

class _FromFriendsDetailSheet extends StatelessWidget {
  final NoticeboardPost post;
  const _FromFriendsDetailSheet({required this.post});

  String _formatDate(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
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
          // Orange header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            decoration: BoxDecoration(
              color: const Color(0xFFE05A00),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Text(post.emoji, style: const TextStyle(fontSize: 30)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post.locationName?.isNotEmpty == true
                            ? post.locationName!
                            : post.displayLabel,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          height: 1.2,
                        ),
                      ),
                      if (post.labelWord?.isNotEmpty == true)
                        Text(
                          post.labelWord!,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.white.withOpacity(0.85),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // City
          if (post.city?.isNotEmpty == true) ...[
            Row(
              children: [
                const Icon(Icons.location_on_outlined,
                    size: 15, color: Color(0xFFE05A00)),
                const SizedBox(width: 6),
                Text(
                  post.city!,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF3E1F00),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
          // Full notes
          if (post.details?.isNotEmpty == true) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF9C4),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                post.details!,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF3D2000),
                  height: 1.6,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
            const SizedBox(height: 14),
          ],
          // Username + date
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFD227).withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '@${post.username}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF975600),
                  ),
                ),
              ),
              const Spacer(),
              Text(
                _formatDate(post.sharedAt),
                style: TextStyle(fontSize: 11, color: Colors.brown.shade400),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(height: 1, color: const Color(0xFFFFD227).withOpacity(0.4)),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(
                foregroundColor: Colors.brown[400],
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: const Text('Close', style: TextStyle(fontSize: 15)),
            ),
          ),
        ],
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
      final tween = Tween(
        begin: begin,
        end: end,
      ).chain(CurveTween(curve: curve));
      final secondaryTween = Tween(
        begin: Offset.zero,
        end: const Offset(-0.3, 0.0),
      ).chain(CurveTween(curve: curve));
      return SlideTransition(
        position: secondaryAnimation.drive(secondaryTween),
        child: SlideTransition(position: animation.drive(tween), child: child),
      );
    },
    transitionDuration: const Duration(milliseconds: 320),
    reverseTransitionDuration: const Duration(milliseconds: 280),
  );
}
