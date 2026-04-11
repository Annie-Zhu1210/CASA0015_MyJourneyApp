import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../models/friend_model.dart';
import '../services/friends_service.dart';

class MyRaceScreen extends StatefulWidget {
  const MyRaceScreen({super.key});

  @override
  State<MyRaceScreen> createState() => _MyRaceScreenState();
}

class _MyRaceScreenState extends State<MyRaceScreen>
    with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  List<Friend> _ranked = []; // sorted by current race type
  late TabController _tabController;

  // 0 = cities, 1 = countries
  int _raceType = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() => _raceType = _tabController.index);
        _rankFriends();
      }
    });
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final friends = await FriendsService.getFriends();
    if (mounted) {
      setState(() {
        _ranked = friends;
        _isLoading = false;
      });
      _rankFriends();
    }
  }

  void _rankFriends() {
    final sorted = List<Friend>.from(_ranked);
    sorted.sort((a, b) {
      final aScore =
          _raceType == 0 ? a.citiesCount : a.countriesCount;
      final bScore =
          _raceType == 0 ? b.citiesCount : b.countriesCount;
      if (bScore != aScore) return bScore.compareTo(aScore);
      // Tie-break: current user first, then by addedAt (earliest = ranked higher)
      if (a.isCurrentUser) return -1;
      if (b.isCurrentUser) return 1;
      return a.addedAt.compareTo(b.addedAt);
    });
    setState(() => _ranked = sorted);
  }

  int _scoreFor(Friend f) =>
      _raceType == 0 ? f.citiesCount : f.countriesCount;

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F0),
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ──────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 16, 16, 0),
              child: Row(
                children: [
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () => Navigator.pop(context),
                    child: const Icon(
                      CupertinoIcons.xmark_circle_fill,
                      color: Color(0xFFD4B896),
                      size: 30,
                    ),
                  ),
                  const Expanded(
                    child: Text(
                      'My Race',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF2C1A00),
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
                  const SizedBox(width: 46), // balance the close button
                ],
              ),
            ),

            const SizedBox(height: 12),

            // ── Race type tabs ───────────────────────────────────────────
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.brown.withOpacity(0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  color: const Color(0xFFFFCD27),
                  borderRadius: BorderRadius.circular(12),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                labelColor: const Color(0xFF7A3D00),
                unselectedLabelColor: Colors.grey.shade400,
                labelStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
                dividerColor: Colors.transparent,
                tabs: const [
                  Tab(text: 'Cities'),
                  Tab(text: 'Countries'),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── Content ──────────────────────────────────────────────────
            Expanded(
              child: _isLoading
                  ? const Center(child: CupertinoActivityIndicator(radius: 14))
                  : _ranked.isEmpty
                      ? const Center(
                          child: Text(
                            'Add friends to start racing!',
                            style: TextStyle(
                              color: Color(0xFFB09070),
                              fontSize: 15,
                            ),
                          ),
                        )
                      : SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                          child: Column(
                            children: [
                              // Podium pyramid (top 3)
                              _Podium(
                                ranked: _ranked,
                                scoreFor: _scoreFor,
                                raceLabel: _raceType == 0
                                    ? 'cities'
                                    : 'countries',
                              ),
                              const SizedBox(height: 20),
                              // Remaining list (4th place onwards)
                              if (_ranked.length > 3)
                                _RemainingList(
                                  ranked: _ranked.sublist(3),
                                  startRank: 4,
                                  scoreFor: _scoreFor,
                                  raceLabel: _raceType == 0
                                      ? 'cities'
                                      : 'countries',
                                ),
                            ],
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Podium (top 3) ────────────────────────────────────────────────────────────

class _Podium extends StatelessWidget {
  final List<Friend> ranked;
  final int Function(Friend) scoreFor;
  final String raceLabel;

  const _Podium({
    required this.ranked,
    required this.scoreFor,
    required this.raceLabel,
  });

  // Medal border colours
  static const Color _gold = Color(0xFFFFD227);
  static const Color _silver = Color(0xFF7A8182);
  static const Color _bronze = Color(0xFF8F614F);

  Color _medalColor(int rank) {
    switch (rank) {
      case 1:
        return _gold;
      case 2:
        return _silver;
      case 3:
        return _bronze;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final first = ranked.isNotEmpty ? ranked[0] : null;
    final second = ranked.length > 1 ? ranked[1] : null;
    final third = ranked.length > 2 ? ranked[2] : null;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
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
      child: Column(
        children: [
          Text(
            raceLabel == 'cities' ? 'Cities Visited' : 'Countries Visited',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF97560A),
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 20),

          // Pyramid layout:
          // Row: [2nd] [1st] [3rd]
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // 2nd place (bottom-left of pyramid)
              _PodiumSpot(
                friend: second,
                rank: 2,
                avatarSize: 62,
                medalColor: _medalColor(2),
                scoreFor: scoreFor,
                raceLabel: raceLabel,
                verticalOffset: 20,
              ),
              const SizedBox(width: 12),
              // 1st place (top-centre)
              _PodiumSpot(
                friend: first,
                rank: 1,
                avatarSize: 80,
                medalColor: _medalColor(1),
                scoreFor: scoreFor,
                raceLabel: raceLabel,
                verticalOffset: 0,
              ),
              const SizedBox(width: 12),
              // 3rd place (bottom-right of pyramid)
              _PodiumSpot(
                friend: third,
                rank: 3,
                avatarSize: 62,
                medalColor: _medalColor(3),
                scoreFor: scoreFor,
                raceLabel: raceLabel,
                verticalOffset: 20,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PodiumSpot extends StatelessWidget {
  final Friend? friend;
  final int rank;
  final double avatarSize;
  final Color medalColor;
  final int Function(Friend) scoreFor;
  final String raceLabel;
  final double verticalOffset; // push down for 2nd/3rd

  const _PodiumSpot({
    required this.friend,
    required this.rank,
    required this.avatarSize,
    required this.medalColor,
    required this.scoreFor,
    required this.raceLabel,
    required this.verticalOffset,
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
    return Padding(
      padding: EdgeInsets.only(top: verticalOffset),
      child: SizedBox(
        width: avatarSize + 16,
        child: Column(
          children: [
            // Avatar with medal border (or transparent placeholder)
            Container(
              width: avatarSize,
              height: avatarSize,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(avatarSize * 0.28),
                border: friend != null
                    ? Border.all(color: medalColor, width: 3)
                    : null,
                color: friend != null
                    ? null
                    : Colors.grey.withOpacity(0.1),
              ),
              child: friend != null
                  ? ClipRRect(
                      borderRadius:
                          BorderRadius.circular(avatarSize * 0.24),
                      child: _AvatarContent(
                        friend: friend!,
                        size: avatarSize - 6,
                      ),
                    )
                  : null, // transparent for empty spots
            ),
            const SizedBox(height: 6),
            // Rank label
            if (friend != null) ...[
              Text(
                _ordinal(rank),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: medalColor,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                friend!.isCurrentUser ? 'You' : friend!.displayName,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2C1A00),
                ),
              ),
              Text(
                '${scoreFor(friend!)} $raceLabel',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey.shade500,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Remaining list (4th place onwards) ───────────────────────────────────────

class _RemainingList extends StatelessWidget {
  final List<Friend> ranked;
  final int startRank;
  final int Function(Friend) scoreFor;
  final String raceLabel;

  const _RemainingList({
    required this.ranked,
    required this.startRank,
    required this.scoreFor,
    required this.raceLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
      child: Column(
        children: List.generate(ranked.length, (index) {
          final friend = ranked[index];
          final rank = startRank + index;
          final isLast = index == ranked.length - 1;
          return Column(
            children: [
              _RankRow(
                friend: friend,
                rank: rank,
                score: scoreFor(friend),
                raceLabel: raceLabel,
              ),
              if (!isLast)
                Padding(
                  padding: const EdgeInsets.only(left: 60),
                  child: Container(
                      height: 0.5, color: Colors.grey.shade100),
                ),
            ],
          );
        }),
      ),
    );
  }
}

class _RankRow extends StatelessWidget {
  final Friend friend;
  final int rank;
  final int score;
  final String raceLabel;

  const _RankRow({
    required this.friend,
    required this.rank,
    required this.score,
    required this.raceLabel,
  });

  @override
  Widget build(BuildContext context) {
    final isMe = friend.isCurrentUser;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: isMe
          ? const Color(0xFFFFCD27).withOpacity(0.08)
          : Colors.transparent,
      child: Row(
        children: [
          // Rank number
          SizedBox(
            width: 28,
            child: Text(
              '$rank',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Colors.grey.shade400,
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Avatar
          _AvatarContent(friend: friend, size: 40),
          const SizedBox(width: 12),
          // Name
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isMe ? 'You' : friend.displayName,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight:
                        isMe ? FontWeight.w700 : FontWeight.w500,
                    color: const Color(0xFF2C1A00),
                  ),
                ),
                if (friend.username.isNotEmpty)
                  Text(
                    '@${friend.username}',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade400,
                    ),
                  ),
              ],
            ),
          ),
          // Score
          Text(
            '$score',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF97560A),
            ),
          ),
          const SizedBox(width: 4),
          Text(
            raceLabel,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade400,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Shared avatar content ─────────────────────────────────────────────────────

class _AvatarContent extends StatelessWidget {
  final Friend friend;
  final double size;

  const _AvatarContent({required this.friend, required this.size});

  ImageProvider? _buildProvider(String url) {
    if (url.isEmpty) return null;
    if (url.startsWith('data:image')) {
      final base64Data = url.split(',').last;
      return MemoryImage(base64Decode(base64Data));
    }
    if (url.startsWith('http')) return NetworkImage(url);
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final url = friend.avatarUrl ?? '';
    final provider = _buildProvider(url);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFFFFCD27).withOpacity(0.25),
        borderRadius: BorderRadius.circular(size * 0.28),
        image: provider != null
            ? DecorationImage(image: provider, fit: BoxFit.cover)
            : null,
      ),
      child: provider == null
          ? Center(
              child: Text(
                friend.displayName.isNotEmpty
                    ? friend.displayName[0].toUpperCase()
                    : '?',
                style: TextStyle(
                  fontSize: size * 0.38,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF7A3D00),
                ),
              ),
            )
          : null,
    );
  }
}