import 'package:flutter/material.dart';
import 'screens/map_screen.dart';
import 'screens/locations_screen.dart';
import 'screens/world_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/login_screen.dart';
import 'widgets/animated_bottom_nav_bar.dart';
import 'models/checkin_location.dart';
import 'services/checkin_database.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'package:flutter/cupertino.dart';
import 'services/user_profile_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'My Journey',
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      debugShowCheckedModeBanner: false,
      // StreamBuilder listens to login/logout in real time
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          // Still waiting to know if user is logged in
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              backgroundColor: Color(0xFFFFF8E7),
              body: Center(
                child: CircularProgressIndicator(
                  color: Color(0xFFF5C842),
                ),
              ),
            );
          }

          // User is logged in → show the main app
          if (snapshot.hasData) {
            return const HomePage();
          }

          // User is not logged in → show login screen
          return const LoginScreen();
        },
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;
  bool _showUsernamePrompt = false;
  String _mapStyle = 'standard';

  final GlobalKey<MapScreenState> _mapKey = GlobalKey<MapScreenState>();
  List<CheckInLocation> _checkIns = [];

  @override
  void initState() {
    super.initState();
    _loadCheckIns();
    _initProfile();
    _loadMapStyle();
  }

  Future<void> _initProfile() async {
    await UserProfileService.ensureProfile();
    final hasUsername = await UserProfileService.hasUsername();
    if (!mounted) return;
    if (!hasUsername) {
      setState(() => _showUsernamePrompt = true);
    }
  }

  Future<void> _loadMapStyle() async {
    final style = await UserProfileService.getMapStyle();
    if (!mounted) return;
    setState(() => _mapStyle = style);
  }

  Future<void> _loadCheckIns() async {
    final checkIns = await CheckInDatabase.loadAll();
    if (!mounted) return;
    setState(() => _checkIns = checkIns);
    _mapKey.currentState?.refresh();
  }

  void _onItemTapped(int index) {
    if (index == 1) _loadCheckIns();
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          body: IndexedStack(
            index: _selectedIndex,
            children: [
              MapScreen(
                key: _mapKey,
                onCheckInsChanged: _loadCheckIns,
                mapStyle: _mapStyle,
              ),
              LocationsScreen(
                checkIns: _checkIns,
                onChanged: _loadCheckIns,
              ),
              const WorldScreen(),
              SettingsScreen(
                onMapStyleChanged: () => _loadMapStyle(),
              ),
            ],
          ),
          extendBody: true,
          bottomNavigationBar: AnimatedBottomNavBar(
            currentIndex: _selectedIndex,
            onTap: _onItemTapped,
            backgroundColor: Colors.white,
            selectedItemColor: const Color.fromARGB(255, 151, 86, 0),
            unselectedItemColor: const Color.fromARGB(255, 255, 205, 39),
            items: const [
              BottomNavigationBarItem(
                  icon: Icon(Icons.map), label: 'Map'),
              BottomNavigationBarItem(
                  icon: Icon(Icons.location_on), label: 'Locations'),
              BottomNavigationBarItem(
                  icon: Icon(Icons.public), label: 'World'),
              BottomNavigationBarItem(
                  icon: Icon(Icons.settings), label: 'Settings'),
            ],
          ),
        ),

        // ── Username prompt overlay ──────────────────────────────────
        if (_showUsernamePrompt)
          _UsernamePromptOverlay(
            onDismiss: () =>
                setState(() => _showUsernamePrompt = false),
            onSaved: () =>
                setState(() => _showUsernamePrompt = false),
          ),
      ],
    );
  }
}

// ── Username prompt overlay widget ────────────────────────────────────────────

class _UsernamePromptOverlay extends StatefulWidget {
  final VoidCallback onDismiss;
  final VoidCallback onSaved;

  const _UsernamePromptOverlay({
    required this.onDismiss,
    required this.onSaved,
  });

  @override
  State<_UsernamePromptOverlay> createState() =>
      _UsernamePromptOverlayState();
}

class _UsernamePromptOverlayState extends State<_UsernamePromptOverlay> {
  final TextEditingController _ctrl = TextEditingController();
  String? _errorText;
  bool _isSaving = false;

  Future<void> _save() async {
    setState(() {
      _isSaving = true;
      _errorText = null;
    });
    final error =
        await UserProfileService.updateUsername(_ctrl.text);
    if (!mounted) return;
    if (error != null) {
      setState(() {
        _errorText = error;
        _isSaving = false;
      });
    } else {
      widget.onSaved();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withOpacity(0.45),
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
           child: Material(
              color: const Color(0xFFFFF8F0),
              borderRadius: BorderRadius.circular(24),
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Icon
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFCD27).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        CupertinoIcons.person_crop_circle_badge_plus,
                        size: 28,
                        color: Color(0xFFE05A00),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Choose a Username',
                      style: TextStyle(
                       fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF2C1A00),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Your friends will use this to find you.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                       color: Colors.grey.shade500,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: _ctrl,
                      maxLength: 20,
                      style: const TextStyle(
                        fontSize: 15,
                        color: Color(0xFF2C1A00),
                      ),
                      decoration: InputDecoration(
                        prefixText: '@',
                        prefixStyle: const TextStyle(
                          fontSize: 15,
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
                              color: Color(0xFFFFCD27), width: 2),
                        ),
                        counterStyle: TextStyle(
                            fontSize: 11, color: Colors.grey.shade400),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _save,
                       style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFFCD27),
                          foregroundColor: const Color(0xFF7A3D00),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: _isSaving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Color(0xFF7A3D00),
                                ),
                              )
                            : const Text(
                                'Save Username',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: widget.onDismiss,
                      child: Text(
                        'Skip for now — you can set this in Settings',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade400,
                       ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}