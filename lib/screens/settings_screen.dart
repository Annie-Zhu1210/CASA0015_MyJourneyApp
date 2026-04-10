import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/cupertino.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import '../services/auth_service.dart';
import '../services/user_profile_service.dart';
import 'dart:io' as dart_io;

class SettingsScreen extends StatefulWidget {
  final VoidCallback? onMapStyleChanged;
  final VoidCallback? onAvatarChanged;

  const SettingsScreen({
    super.key,
    this.onMapStyleChanged,
    this.onAvatarChanged,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  Map<String, dynamic>? _profile;
  bool _isLoading = true;
  String _selectedMapStyle = 'standard';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final profile = await UserProfileService.getProfile();
    final mapStyle = await UserProfileService.getMapStyle();
    if (!mounted) return;
    setState(() {
      _profile = profile;
      _selectedMapStyle = mapStyle;
      _isLoading = false;
    });
  }

  // ── Avatar picker ────────────────────────────────────────────────────────
  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );
    if (picked == null) return;

    if (mounted) {
      setState(() {
        _profile = {...?_profile, 'photoUrl': picked.path};
      });
      await UserProfileService.updatePhotoUrl(picked.path);
      widget.onAvatarChanged?.call();
    }
  }

  // ── Username edit sheet ──────────────────────────────────────────────────
  Future<void> _showUsernameSheet() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _UsernameSheet(
        currentUsername: _profile?['username'] as String? ?? '',
      ),
    );
    // Sheet is fully closed — safe to reload
    await _loadData();
  }

  // ── Map style selector ───────────────────────────────────────────────────
  Future<void> _setMapStyle(String style) async {
    await UserProfileService.saveMapStyle(style);
    setState(() => _selectedMapStyle = style);
    widget.onMapStyleChanged?.call();
  }

  // ── Logout ───────────────────────────────────────────────────────────────
  Future<void> _logout() async {
    final confirm = await _showConfirmDialog(
      title: 'Log Out',
      message: 'Are you sure you want to log out?',
      confirmLabel: 'Log Out',
      isDestructive: false,
    );
    if (confirm == true) await AuthService.signOut();
  }

  // ── Delete account ───────────────────────────────────────────────────────
  Future<void> _deleteAccount() async {
    final confirm = await _showConfirmDialog(
      title: 'Delete Account',
      message:
          'This will permanently delete your account and all your data. This cannot be undone.',
      confirmLabel: 'Delete',
      isDestructive: true,
    );
    if (confirm == true) await AuthService.deleteAccount();
  }

  Future<bool?> _showConfirmDialog({
    required String title,
    required String message,
    required String confirmLabel,
    required bool isDestructive,
  }) {
    return showCupertinoDialog<bool>(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: isDestructive,
            onPressed: () => Navigator.pop(context, true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CupertinoActivityIndicator())
            : CustomScrollView(
                slivers: [
                  // ── Title ──────────────────────────────────────────────
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                      child: const Text(
                        'Settings',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF2C1A00),
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                  ),

                  // ── Profile card ───────────────────────────────────────
                  SliverToBoxAdapter(child: _buildProfileCard()),

                  // ── Preferences section ────────────────────────────────
                  SliverToBoxAdapter(child: _buildSectionLabel('Preferences')),
                  SliverToBoxAdapter(child: _buildMapStyleCard()),

                  // ── Account section ────────────────────────────────────
                  SliverToBoxAdapter(child: _buildSectionLabel('Account')),
                  SliverToBoxAdapter(child: _buildAccountCard()),

                  const SliverToBoxAdapter(child: SizedBox(height: 40)),
                ],
              ),
      ),
    );
  }

  // ── Profile card ──────────────────────────────────────────────────────────

  Widget _buildProfileCard() {
    final user = FirebaseAuth.instance.currentUser;
    final photoUrl = _profile?['photoUrl'] as String? ?? user?.photoURL ?? '';
    final username = _profile?['username'] as String? ?? '';
    final friendCode = _profile?['friendCode'] as String? ?? '—';
    final displayName = _profile?['displayName'] as String? ?? 'Explorer';

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.brown.withOpacity(0.07),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          // ── Avatar ───────────────────────────────────────────────────
          GestureDetector(
            onTap: _pickAvatar,
            child: Stack(
              children: [
                Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    color: const Color(0xFFFFCD27).withOpacity(0.3),
                    image: photoUrl.isNotEmpty
                        ? DecorationImage(
                            image: photoUrl.startsWith('/')
                                ? FileImage(dart_io.File(photoUrl))
                                      as ImageProvider
                                : NetworkImage(photoUrl),
                            fit: BoxFit.cover,
                          )
                        : null,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.brown.withOpacity(0.12),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: photoUrl.isEmpty
                      ? Center(
                          child: Text(
                            displayName.isNotEmpty
                                ? displayName[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF7A3D00),
                            ),
                          ),
                        )
                      : null,
                ),
                // Camera badge
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFCD27),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Icon(
                      CupertinoIcons.camera_fill,
                      size: 14,
                      color: Color(0xFF7A3D00),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ── Username (tappable) ───────────────────────────────────────
          GestureDetector(
            onTap: _showUsernameSheet,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  username.isNotEmpty ? '@$username' : 'Set a username',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: username.isNotEmpty
                        ? const Color(0xFF2C1A00)
                        : Colors.grey.shade400,
                  ),
                ),
                const SizedBox(width: 6),
                Icon(
                  CupertinoIcons.pencil,
                  size: 16,
                  color: Colors.grey.shade400,
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // ── Friend code ───────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF3D0),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  CupertinoIcons.person_badge_plus,
                  size: 14,
                  color: Color(0xFFE05A00),
                ),
                const SizedBox(width: 6),
                Text(
                  friendCode,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFE05A00),
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: friendCode));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Friend code copied!'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  child: Icon(
                    CupertinoIcons.doc_on_doc,
                    size: 14,
                    color: Colors.grey.shade400,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 4),
          Text(
            'Share this code so friends can find you',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
          ),
        ],
      ),
    );
  }

  // ── Map style card ────────────────────────────────────────────────────────

  Widget _buildMapStyleCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.brown.withOpacity(0.07),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildMapStyleOption(
            label: 'Standard',
            icon: CupertinoIcons.map,
            value: 'standard',
            isFirst: true,
            isLast: false,
          ),
          _buildDivider(),
          _buildMapStyleOption(
            label: 'Satellite',
            icon: CupertinoIcons.globe,
            value: 'satellite',
            isFirst: false,
            isLast: false,
          ),
          _buildDivider(),
          _buildMapStyleOption(
            label: 'Dark',
            icon: CupertinoIcons.moon_fill,
            value: 'dark',
            isFirst: false,
            isLast: true,
          ),
        ],
      ),
    );
  }

  Widget _buildMapStyleOption({
    required String label,
    required IconData icon,
    required String value,
    required bool isFirst,
    required bool isLast,
  }) {
    final isSelected = _selectedMapStyle == value;
    return GestureDetector(
      onTap: () => _setMapStyle(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(
            top: isFirst ? const Radius.circular(20) : Radius.zero,
            bottom: isLast ? const Radius.circular(20) : Radius.zero,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: const Color(0xFFE05A00)),
            const SizedBox(width: 14),
            Text(
              label,
              style: const TextStyle(fontSize: 15, color: Color(0xFF2C1A00)),
            ),
            const Spacer(),
            if (isSelected)
              const Icon(
                CupertinoIcons.checkmark_alt,
                size: 18,
                color: Color(0xFFFFCD27),
              ),
          ],
        ),
      ),
    );
  }

  // ── Account card ──────────────────────────────────────────────────────────

  Widget _buildAccountCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.brown.withOpacity(0.07),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          // Logout
          GestureDetector(
            onTap: _logout,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  const Icon(
                    CupertinoIcons.square_arrow_left,
                    size: 20,
                    color: Color(0xFFE05A00),
                  ),
                  const SizedBox(width: 14),
                  const Text(
                    'Log Out',
                    style: TextStyle(fontSize: 15, color: Color(0xFF2C1A00)),
                  ),
                  const Spacer(),
                  Icon(
                    CupertinoIcons.chevron_right,
                    size: 14,
                    color: Colors.grey.shade300,
                  ),
                ],
              ),
            ),
          ),
          _buildDivider(),
          // Delete account
          GestureDetector(
            onTap: _deleteAccount,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius:
                    BorderRadius.vertical(bottom: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  const Icon(CupertinoIcons.trash,
                      size: 20, color: Colors.red),
                  const SizedBox(width: 14),
                  const Text(
                    'Delete Account',
                    style: TextStyle(fontSize: 15, color: Colors.red),
                  ),
                  const Spacer(),
                  Icon(
                    CupertinoIcons.chevron_right,
                    size: 14,
                    color: Colors.grey.shade300,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Widget _buildSectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Colors.grey.shade500,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Padding(
      padding: const EdgeInsets.only(left: 50),
      child: Container(height: 0.5, color: Colors.grey.shade200),
    );
  }
}


class _UsernameSheet extends StatefulWidget {
  final String currentUsername;
  const _UsernameSheet({required this.currentUsername});

  @override
  State<_UsernameSheet> createState() => _UsernameSheetState();
}

class _UsernameSheetState extends State<_UsernameSheet> {
  late final TextEditingController _controller;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.currentUsername);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFFFFF8F0),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
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
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Set Username',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF2C1A00),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Letters, numbers, and underscores only. 3–20 characters.',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
            ),
            const SizedBox(height: 16),
            Material(
              color: Colors.transparent,
              child: TextField(
                controller: _controller,
                autofocus: true,
                maxLength: 20,
                style: const TextStyle(
                  fontSize: 16,
                  color: Color(0xFF2C1A00),
                ),
                decoration: InputDecoration(
                  prefixText: '@',
                  prefixStyle: const TextStyle(
                    fontSize: 16,
                    color: Color(0xFFE05A00),
                    fontWeight: FontWeight.w600,
                  ),
                  hintText: 'your_username',
                  errorText: _errorText,
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(
                      color: Color(0xFFFFCD27),
                      width: 2,
                    ),
                  ),
                  counterStyle: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade400,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFCD27),
                  foregroundColor: const Color(0xFF7A3D00),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () async {
                  final error = await UserProfileService.updateUsername(
                    _controller.text,
                  );
                  if (error != null) {
                    setState(() => _errorText = error);
                  } else {
                    if (mounted) Navigator.pop(context);
                  }
                },
                child: const Text(
                  'Save Username',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}