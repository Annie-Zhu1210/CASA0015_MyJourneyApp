import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'login_screen.dart';
import 'home_page.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {

  late final AnimationController _globeCtrl;
  late final AnimationController _titleCtrl;
  late final AnimationController _taglineCtrl;

  late final Animation<double> _globeScale;
  late final Animation<double> _globeOpacity;
  late final Animation<double> _titleOpacity;
  late final Animation<Offset> _titleSlide;
  late final Animation<double> _taglineOpacity;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _runSequence();
  }

  void _setupAnimations() {
    _globeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _globeScale = Tween<double>(begin: 0.75, end: 1.0).animate(
      CurvedAnimation(parent: _globeCtrl, curve: Curves.easeOutBack),
    );
    _globeOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _globeCtrl, curve: Curves.easeOut),
    );

    _titleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _titleOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _titleCtrl, curve: Curves.easeOut),
    );
    _titleSlide = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _titleCtrl, curve: Curves.easeOut));

    _taglineCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _taglineOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _taglineCtrl, curve: Curves.easeOut),
    );
  }

  Future<void> _runSequence() async {
    // Start listening to auth state immediately — runs in parallel with animation
    final authFuture = FirebaseAuth.instance.authStateChanges().first;

    await Future.delayed(const Duration(milliseconds: 100));
    if (!mounted) return;
    _globeCtrl.forward();

    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;
    _titleCtrl.forward();

    await Future.delayed(const Duration(milliseconds: 250));
    if (!mounted) return;
    _taglineCtrl.forward();

    // Always wait for the full animation to finish (900ms hold after tagline),
    // AND wait for Firebase auth to resolve — whichever is longer wins.
    // Total minimum on screen = 100 + 400 + 250 + 900 = 1650ms
    final results = await Future.wait([
      authFuture,
      Future.delayed(const Duration(milliseconds: 900)),
    ]);
    if (!mounted) return;

    final user = results[0] as User?;
    _navigate(user);
  }

  void _navigate(User? user) {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) =>
            user != null ? const HomePage() : const LoginScreen(),
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  @override
  void dispose() {
    _globeCtrl.dispose();
    _titleCtrl.dispose();
    _taglineCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8EF),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0),
          child: Column(
            children: [
              const Spacer(flex: 2),

              AnimatedBuilder(
                animation: _globeCtrl,
                builder: (context, child) => Opacity(
                  opacity: _globeOpacity.value,
                  child: Transform.scale(scale: _globeScale.value, child: child),
                ),
                child: Image.asset(
                  'assets/images/Globe_with_flying_airplane_icon.png',
                  width: 320,
                  height: 320,
                ),
              ),

              const SizedBox(height: 8),

              AnimatedBuilder(
                animation: _titleCtrl,
                builder: (context, child) => Opacity(
                  opacity: _titleOpacity.value,
                  child: SlideTransition(position: _titleSlide, child: child),
                ),
                child: Text(
                  'My Journey',
                  style: GoogleFonts.comfortaa(
                    fontSize: 36,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFFE05A00),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              AnimatedBuilder(
                animation: _taglineCtrl,
                builder: (context, child) =>
                    Opacity(opacity: _taglineOpacity.value, child: child),
                child: Text(
                  'Recording the beauty of life — a personal memoir of your journey',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.comfortaa(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: const Color(0xFFB07040),
                  ),
                ),
              ),

              const Spacer(flex: 3),
            ],
          ),
        ),
      ),
    );
  }
}