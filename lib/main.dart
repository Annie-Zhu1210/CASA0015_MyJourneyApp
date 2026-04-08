import 'package:flutter/material.dart';
import 'screens/map_screen.dart';
import 'screens/locations_screen.dart';
import 'screens/world_screen.dart';
import 'screens/settings_screen.dart';
import 'widgets/animated_bottom_nav_bar.dart';
import 'models/checkin_location.dart';
import 'services/checkin_database.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'My Journey',
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      home: const HomePage(),
      debugShowCheckedModeBanner: false,
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

  // GlobalKey lets us call refresh() on MapScreen from outside
  final GlobalKey<MapScreenState> _mapKey = GlobalKey<MapScreenState>();

  // ── Shared check-ins state ───────────────────────────────────────────────
  List<CheckInLocation> _checkIns = [];

  @override
  void initState() {
    super.initState();
    _loadCheckIns();
  }

  Future<void> _loadCheckIns() async {
    final checkIns = await CheckInDatabase.loadAll();
    if (!mounted) return;
    setState(() => _checkIns = checkIns);
    // Also tell the map to reload its own internal marker list
    _mapKey.currentState?.refresh();
  }

  void _onItemTapped(int index) {
    if (index == 1) _loadCheckIns();
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          MapScreen(key: _mapKey, onCheckInsChanged: _loadCheckIns),
          LocationsScreen(
            checkIns: _checkIns,
            onChanged: _loadCheckIns,
          ),
          const WorldScreen(),
          const SettingsScreen(),
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
          BottomNavigationBarItem(icon: Icon(Icons.map), label: 'Map'),
          BottomNavigationBarItem(
              icon: Icon(Icons.location_on), label: 'Locations'),
          BottomNavigationBarItem(icon: Icon(Icons.public), label: 'World'),
          BottomNavigationBarItem(
              icon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }
}