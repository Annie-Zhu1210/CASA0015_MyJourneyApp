import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../models/friend_model.dart';
import '../services/friends_service.dart';

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  bool _isLoading = true;
  List<Friend> _friends = [];

  @override
  void initState() {
    super.initState();
    _loadFriends();
  }

  Future<void> _loadFriends() async {
    setState(() => _isLoading = true);
    final friends = await FriendsService.getFriends();
    if (mounted) {
      setState(() {
        _friends = friends;
        _isLoading = false;
      });
    }
  }

  // ── Add friend dialog ─────────────────────────────────────────────────────

  Future<void> _showAddFriendDialog() async {
    final controller = TextEditingController();
    String? errorText;
    bool isSearching = false;
    Friend? foundFriend;

    await showCupertinoDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => CupertinoAlertDialog(
          title: const Text('Add Friend'),
          content: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Enter a username (@username) or friend code (JOURNEY-XXXX)',
                  style: TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 12),
                CupertinoTextField(
                  controller: controller,
                  placeholder: '@username or JOURNEY-XXXX',
                  autofocus: true,
                  autocorrect: false,
                  onChanged: (_) {
                    setDialogState(() {
                      errorText = null;
                      foundFriend = null;
                    });
                  },
                ),
                if (errorText != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    errorText!,
                    style: const TextStyle(
                        fontSize: 12, color: CupertinoColors.destructiveRed),
                  ),
                ],
                if (foundFriend != null) ...[
                  const SizedBox(height: 10),
                  _FoundFriendPreview(friend: foundFriend!),
                ],
                if (isSearching)
                  const Padding(
                    padding: EdgeInsets.only(top: 10),
                    child: CupertinoActivityIndicator(),
                  ),
              ],
            ),
          ),
          actions: [
            CupertinoDialogAction(
              isDestructiveAction: true,
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            CupertinoDialogAction(
              onPressed: isSearching
                  ? null
                  : () async {
                      final query = controller.text.trim();
                      if (query.isEmpty) return;

                      setDialogState(() {
                        isSearching = true;
                        errorText = null;
                        foundFriend = null;
                      });

                      final found =
                          await FriendsService.searchUser(query);

                      if (!ctx.mounted) return;

                      if (found == null) {
                        setDialogState(() {
                          isSearching = false;
                          errorText = 'No user found with that username or code.';
                        });
                        return;
                      }

                      // Check already friends
                      final alreadyFriend =
                          _friends.any((f) => f.id == found.id);
                      if (alreadyFriend) {
                        setDialogState(() {
                          isSearching = false;
                          errorText = 'You\'re already friends!';
                        });
                        return;
                      }

                      // Add immediately
                      final success =
                          await FriendsService.addFriend(found.id);
                      if (!ctx.mounted) return;

                      if (success) {
                        Navigator.pop(ctx);
                        await _loadFriends(); // refresh list
                      } else {
                        setDialogState(() {
                          isSearching = false;
                          errorText = 'Could not add friend. Try again.';
                        });
                      }
                    },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );

    controller.dispose();
  }

  // ── Friend action sheet ───────────────────────────────────────────────────

  Future<void> _showFriendOptions(Friend friend) async {
    await showCupertinoModalPopup(
      context: context,
      builder: (_) => CupertinoActionSheet(
        title: Text(friend.displayName),
        message: Text(
          friend.username.isNotEmpty ? '@${friend.username}' : 'No username set',
        ),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () async {
              Navigator.pop(context);
              await FriendsService.toggleHideLocation(
                  friend.id, friend.isLocationHidden);
              await _loadFriends();
            },
            child: Text(
              friend.isLocationHidden
                  ? 'Show My Location to Them'
                  : 'Hide My Location from Them',
            ),
          ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () async {
              Navigator.pop(context);
              await _confirmRemove(friend);
            },
            child: const Text('Remove Friend'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  Future<void> _confirmRemove(Friend friend) async {
    final confirm = await showCupertinoDialog<bool>(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: const Text('Remove Friend'),
        content: Text(
            'Remove ${friend.displayName} from your friends list?'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await FriendsService.removeFriend(friend.id);
      await _loadFriends();
    }
  }

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
                  // Exit button (top left)
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
                      'Friends',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF2C1A00),
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
                  // Add friend button (top right)
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: _showAddFriendDialog,
                    child: const Icon(
                      CupertinoIcons.person_badge_plus,
                      color: Color(0xFFE05A00),
                      size: 28,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // ── Friend count subtitle ────────────────────────────────────
            Text(
              _isLoading
                  ? ''
                  : '${_friends.length} ${_friends.length == 1 ? 'person' : 'people'}',
              style: TextStyle(
                fontSize: 13,
                color: Colors.brown.shade300,
              ),
            ),

            const SizedBox(height: 12),

            // ── List ─────────────────────────────────────────────────────
            Expanded(
              child: _isLoading
                  ? const Center(child: CupertinoActivityIndicator(radius: 14))
                  : _friends.isEmpty
                      ? const Center(
                          child: Text(
                            'No friends yet.\nTap + to add someone!',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Color(0xFFB09070),
                              fontSize: 15,
                              height: 1.5,
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 4),
                          itemCount: _friends.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (_, index) {
                            final friend = _friends[index];
                            return _FriendTile(
                              friend: friend,
                              onTap: friend.isCurrentUser
                                  ? null
                                  : () => _showFriendOptions(friend),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Friend tile ───────────────────────────────────────────────────────────────

class _FriendTile extends StatelessWidget {
  final Friend friend;
  final VoidCallback? onTap;

  const _FriendTile({required this.friend, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.brown.withOpacity(0.07),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            // Avatar
            _AvatarWidget(
              avatarUrl: friend.avatarUrl,
              displayName: friend.displayName,
              size: 48,
            ),
            const SizedBox(width: 12),
            // Name + username
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        friend.displayName,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF2C1A00),
                        ),
                      ),
                      if (friend.isCurrentUser) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFCD27).withOpacity(0.25),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'You',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF97560A),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    friend.username.isNotEmpty
                        ? '@${friend.username}'
                        : 'No username set',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ),
            // Hidden indicator or chevron
            if (!friend.isCurrentUser)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (friend.isLocationHidden)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Icon(
                        CupertinoIcons.eye_slash,
                        size: 15,
                        color: Colors.grey.shade400,
                      ),
                    ),
                  Icon(
                    CupertinoIcons.ellipsis,
                    size: 18,
                    color: Colors.grey.shade400,
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

// ── Found friend preview (inside add dialog) ──────────────────────────────────

class _FoundFriendPreview extends StatelessWidget {
  final Friend friend;
  const _FoundFriendPreview({required this.friend});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3D0),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _AvatarWidget(
            avatarUrl: friend.avatarUrl,
            displayName: friend.displayName,
            size: 36,
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                friend.displayName,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2C1A00),
                ),
              ),
              Text(
                friend.username.isNotEmpty ? '@${friend.username}' : '',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Shared avatar widget ──────────────────────────────────────────────────────

class _AvatarWidget extends StatelessWidget {
  final String? avatarUrl;
  final String displayName;
  final double size;

  const _AvatarWidget({
    required this.avatarUrl,
    required this.displayName,
    required this.size,
  });

  ImageProvider? _buildProvider(String url) {
    if (url.isEmpty) return null;
    if (url.startsWith('data:image')) {
      final base64Data = url.split(',').last;
      return MemoryImage(base64Decode(base64Data));
    } else if (url.startsWith('/')) {
      return null; // temp path — ignore
    }
    return NetworkImage(url);
  }

  @override
  Widget build(BuildContext context) {
    final url = avatarUrl ?? '';
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
                displayName.isNotEmpty
                    ? displayName[0].toUpperCase()
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

// Public avatar widget for use in other screens
class FriendAvatarWidget extends StatelessWidget {
  final String? avatarUrl;
  final String displayName;
  final double size;

  const FriendAvatarWidget({
    super.key,
    required this.avatarUrl,
    required this.displayName,
    required this.size,
  });

  ImageProvider? _buildProvider(String url) {
    if (url.isEmpty) return null;
    if (url.startsWith('data:image')) {
      final base64Data = url.split(',').last;
      return MemoryImage(base64Decode(base64Data));
    } else if (url.startsWith('/')) {
      return null;
    }
    return NetworkImage(url);
  }

  @override
  Widget build(BuildContext context) {
    final url = avatarUrl ?? '';
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
                displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
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