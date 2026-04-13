import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../services/exploration_service.dart';
import '../services/user_profile_service.dart';
import '../services/geocoding_service.dart';
import '../services/friends_service.dart';
import '../services/noticeboard_service.dart';
import 'cities_visited_screen.dart';
import 'countries_visited_screen.dart';
import 'friends_screen.dart';
import 'my_race_screen.dart';

class WorldScreen extends StatefulWidget {
  const WorldScreen({super.key});

  @override
  State<WorldScreen> createState() => _WorldScreenState();
}

class _WorldScreenState extends State<WorldScreen> {
  bool _isLoading = true;
  List<PlaceInfo> _cities = [];
  List<PlaceInfo> _countries = [];
  int _friendCount = 1;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() => _isLoading = true);
    try {
      final points = await ExplorationService.loadVisitedPoints();
      final cities = await GeocodingService.getCitiesFromPoints(points);
      final countries = await GeocodingService.getCountriesFromPoints(points);
      final friendCount = await FriendsService.getFriendCount();

      await UserProfileService.updateExplorationCounts(
        citiesCount: cities.length,
        countriesCount: countries.length,
      );

      if (mounted) {
        setState(() {
          _cities = cities;
          _countries = countries;
          _friendCount = friendCount < 1 ? 1 : friendCount;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  int get _myRankByCities => 1;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F0),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // ── Header ──────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'My World',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF2C1A00),
                        letterSpacing: -0.5,
                      ),
                    ),
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: _isLoading ? null : _loadStats,
                      child: const Icon(
                        CupertinoIcons.arrow_clockwise,
                        color: Color(0xFFFFCD27),
                        size: 22,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
                child: Text(
                  'Based on your exploration journey',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.brown.shade400,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
            ),

            // ── 2×2 Stats Grid ───────────────────────────────────────────
            SliverToBoxAdapter(
              child: _isLoading
                  ? const SizedBox(
                      height: 360,
                      child: Center(
                        child: CupertinoActivityIndicator(radius: 16),
                      ),
                    )
                  : Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: SizedBox(
                        height: 360,
                        child: Column(
                          children: [
                            // Row 1
                            Expanded(
                              child: Row(
                                children: [
                                  Expanded(
                                    child: _StatCard(
                                      icon: CupertinoIcons.building_2_fill,
                                      iconColor: const Color(0xFFFF8C42),
                                      title: 'Cities Visited',
                                      value: '${_cities.length}',
                                      description: _cities.isEmpty
                                          ? 'Start exploring!'
                                          : 'You have explored ${_cities.length} ${_cities.length == 1 ? 'city' : 'cities'}',
                                      onTap: () => Navigator.push(
                                        context,
                                        CupertinoPageRoute(
                                          builder: (_) => CitiesVisitedScreen(
                                            cities: _cities,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _StatCard(
                                      icon: CupertinoIcons.globe,
                                      iconColor: const Color(0xFF4CAF50),
                                      title: 'Countries Visited',
                                      value: '${_countries.length}',
                                      description: _countries.isEmpty
                                          ? 'Start exploring!'
                                          : 'You have explored ${_countries.length} ${_countries.length == 1 ? 'country' : 'countries'}',
                                      onTap: () => Navigator.push(
                                        context,
                                        CupertinoPageRoute(
                                          builder: (_) => CountriesVisitedScreen(
                                            countries: _countries,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            // Row 2
                            Expanded(
                              child: Row(
                                children: [
                                  Expanded(
                                    child: _AddFriendsCard(
                                      friendCount: _friendCount,
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          CupertinoPageRoute(
                                            builder: (_) => const FriendsScreen(),
                                          ),
                                        ).then((_) => _loadStats());
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _MyRaceCard(
                                      rank: _myRankByCities,
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          CupertinoPageRoute(
                                            builder: (_) => const MyRaceScreen(),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 28)),

            // ── Noticeboard section header ────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 4),
                child: Row(
                  children: [
                    Container(
                      width: 4,
                      height: 20,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE05A00),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'From Friends',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF2C1A00),
                        letterSpacing: -0.3,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'Public noticeboard',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.brown.shade400,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 4)),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                child: Text(
                  'Tap a card to view details and import. Long press to delete your own posts.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.brown.shade400,
                    height: 1.4,
                  ),
                ),
              ),
            ),

            // ── Noticeboard feed ──────────────────────────────────────────
            _NoticeboardFeed(),

            // Bottom padding for nav bar
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// NOTICEBOARD FEED
// ─────────────────────────────────────────────────────────────────────────────

class _NoticeboardFeed extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<NoticeboardPost>>(
      stream: NoticeboardService.feedStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(child: CupertinoActivityIndicator(radius: 12)),
            ),
          );
        }

        if (snapshot.hasError) {
          return SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: Center(
                child: Text(
                  'Could not load the noticeboard.',
                  style: TextStyle(fontSize: 13, color: Colors.brown.shade400),
                ),
              ),
            ),
          );
        }

        final posts = snapshot.data ?? [];

        if (posts.isEmpty) {
          return SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
              child: Column(
                children: [
                  Icon(CupertinoIcons.map_pin_ellipse,
                      size: 40, color: Colors.brown.shade300),
                  const SizedBox(height: 12),
                  Text(
                    'Nothing shared yet',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.brown.shade400,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Be the first! Share a location\nfrom the Locations screen.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.brown.shade300,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) => Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: _NoticeboardCard(post: posts[index]),
            ),
            childCount: posts.length,
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// NOTICEBOARD CARD
// ─────────────────────────────────────────────────────────────────────────────

class _NoticeboardCard extends StatelessWidget {
  final NoticeboardPost post;

  const _NoticeboardCard({required this.post});

  String _formatDate(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }

  Future<void> _showDetailDialog(BuildContext context) async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _NoticeboardDetailSheet(post: post),
    );
  }

  Future<void> _showDeleteOption(BuildContext context) async {
    final isOwner = await NoticeboardService.isCurrentUserPost(post);
    if (!isOwner || !context.mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFFFFFBEE),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Delete Post?',
          style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF3D2000)),
        ),
        content: Text(
          'Remove "${post.locationName ?? post.displayLabel}" from the noticeboard?',
          style: TextStyle(
              fontSize: 14, color: Colors.brown.shade600, height: 1.5),
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
            child: const Text('Delete',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await NoticeboardService.deletePost(post.id);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Post deleted.'),
          backgroundColor: Color(0xFF975600),
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.fromLTRB(16, 0, 16, 600),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showDetailDialog(context),
      onLongPress: () => _showDeleteOption(context),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.brown.withOpacity(0.07),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            // ── Emoji pill ─────────────────────────────────────────
            Container(
              width: 70,
              height: 80,
              decoration: const BoxDecoration(
                color: Color(0xFFFFD227),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(18),
                  bottomLeft: Radius.circular(18),
                ),
              ),
              child: Center(
                child: Text(post.emoji,
                    style: const TextStyle(fontSize: 28)),
              ),
            ),
            Container(
              width: 3,
              height: 80,
              color: const Color(0xFFFFD227).withOpacity(0.5),
            ),
            // ── Content ────────────────────────────────────────────
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      post.locationName?.isNotEmpty == true
                          ? post.locationName!
                          : post.displayLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF2C1A00),
                      ),
                    ),
                    const SizedBox(height: 3),
                    if (post.city?.isNotEmpty == true)
                      Row(
                        children: [
                          Icon(Icons.location_on_outlined,
                              size: 12,
                              color: const Color(0xFFE05A00).withOpacity(0.8)),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              post.city!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 11, color: Colors.brown.shade500),
                            ),
                          ),
                        ],
                      ),
                    if (post.details?.isNotEmpty == true) ...[
                      const SizedBox(height: 4),
                      Text(
                        post.details!.length > 60
                            ? '${post.details!.substring(0, 60)}…'
                            : post.details!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.brown.shade400,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFD227).withOpacity(0.3),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '@${post.username}',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF975600),
                            ),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          _formatDate(post.sharedAt),
                          style: TextStyle(
                              fontSize: 10, color: Colors.brown.shade300),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            // ── Chevron ────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Icon(
                CupertinoIcons.chevron_right,
                size: 16,
                color: const Color(0xFFE05A00).withOpacity(0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// NOTICEBOARD DETAIL BOTTOM SHEET
// ─────────────────────────────────────────────────────────────────────────────

class _NoticeboardDetailSheet extends StatefulWidget {
  final NoticeboardPost post;
  const _NoticeboardDetailSheet({required this.post});

  @override
  State<_NoticeboardDetailSheet> createState() =>
      _NoticeboardDetailSheetState();
}

class _NoticeboardDetailSheetState extends State<_NoticeboardDetailSheet> {
  bool _isImporting = false;

  String _formatDate(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }

  Future<void> _import() async {
    setState(() => _isImporting = true);
    try {
      await NoticeboardService.importPost(widget.post);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${widget.post.locationName ?? widget.post.displayLabel} added to From Friends!',
            ),
            backgroundColor: const Color(0xFF975600),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 600),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isImporting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to import location.'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            margin: EdgeInsets.fromLTRB(16, 0, 16, 600),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;

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
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 20),

          // ── Header: emoji + name ───────────────────────────────────
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

          // ── City ───────────────────────────────────────────────────
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

          // ── Full notes ─────────────────────────────────────────────
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

          // ── Shared by + date ───────────────────────────────────────
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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

          Container(
            height: 1,
            color: const Color(0xFFFFD227).withOpacity(0.4),
          ),
          const SizedBox(height: 16),

          // ── Import button ──────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isImporting ? null : _import,
              icon: _isImporting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFF3D2000),
                      ),
                    )
                  : const Icon(Icons.download_rounded, size: 20),
              label: Text(
                _isImporting ? 'Importing…' : 'Import to From Friends',
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 15),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFD24B),
                foregroundColor: const Color(0xFF3D2000),
                disabledBackgroundColor: Colors.grey[200],
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // ── Close ──────────────────────────────────────────────────
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

// ─────────────────────────────────────────────────────────────────────────────
// EXISTING WIDGETS (unchanged)
// ─────────────────────────────────────────────────────────────────────────────

class _AddFriendsCard extends StatelessWidget {
  final int friendCount;
  final VoidCallback onTap;

  const _AddFriendsCard({
    required this.friendCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.brown.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2196F3).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      CupertinoIcons.person_2_fill,
                      color: Color(0xFF2196F3),
                      size: 22,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '$friendCount',
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF2C1A00),
                      height: 1.0,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Friends',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF97560A),
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Add friends here.',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade500,
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Positioned(
              top: 12,
              right: 12,
              child: Icon(
                CupertinoIcons.chevron_right,
                size: 14,
                color: Colors.grey.shade400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MyRaceCard extends StatelessWidget {
  final int rank;
  final VoidCallback onTap;

  const _MyRaceCard({
    required this.rank,
    required this.onTap,
  });

  String _ordinal(int n) {
    if (n >= 11 && n <= 13) return '${n}th';
    switch (n % 10) {
      case 1:
        return '${n}st';
      case 2:
        return '${n}nd';
      case 3:
        return '${n}rd';
      default:
        return '${n}th';
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.brown.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFCD27).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      CupertinoIcons.rosette,
                      color: Color(0xFFFFCD27),
                      size: 22,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    _ordinal(rank),
                    style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF2C1A00),
                      height: 1.0,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'My Race',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF97560A),
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Cities visited ranking',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade500,
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Positioned(
              top: 12,
              right: 12,
              child: Icon(
                CupertinoIcons.chevron_right,
                size: 14,
                color: Colors.grey.shade400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String value;
  final String description;
  final VoidCallback? onTap;

  const _StatCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.value,
    required this.description,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.brown.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: iconColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: iconColor, size: 22),
                  ),
                  const Spacer(),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF2C1A00),
                      height: 1.0,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF97560A),
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade500,
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (onTap != null)
              Positioned(
                top: 12,
                right: 12,
                child: Icon(
                  CupertinoIcons.chevron_right,
                  size: 14,
                  color: Colors.grey.shade400,
                ),
              ),
          ],
        ),
      ),
    );
  }
}