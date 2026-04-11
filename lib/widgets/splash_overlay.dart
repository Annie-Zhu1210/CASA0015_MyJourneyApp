import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class SplashOverlay extends StatefulWidget {
  final Widget child;

  const SplashOverlay({super.key, required this.child});

  @override
  State<SplashOverlay> createState() => _SplashOverlayState();
}

class _SplashOverlayState extends State<SplashOverlay>
    with TickerProviderStateMixin {

  // Whether the splash is still visible
  bool _visible = true;

  // Entrance animations
  late final AnimationController _globeCtrl;
  late final AnimationController _titleCtrl;
  late final AnimationController _taglineCtrl;

  // Fade-out of the entire overlay
  late final AnimationController _fadeOutCtrl;

  late final Animation<double> _globeScale;
  late final Animation<double> _globeOpacity;
  late final Animation<double> _titleOpacity;
  late final Animation<Offset> _titleSlide;
  late final Animation<double> _taglineOpacity;
  late final Animation<double> _overlayFade;

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

    // Fade out the whole overlay at the end
    _fadeOutCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _overlayFade = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _fadeOutCtrl, curve: Curves.easeIn),
    );
  }

  Future<void> _runSequence() async {
    // Staggered entrance
    await Future.delayed(const Duration(milliseconds: 100));
    if (!mounted) return;
    _globeCtrl.forward();

    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;
    _titleCtrl.forward();

    await Future.delayed(const Duration(milliseconds: 250));
    if (!mounted) return;
    _taglineCtrl.forward();

    // Hold so the user can read it
    await Future.delayed(const Duration(milliseconds: 1800));
    if (!mounted) return;

    // Fade out the overlay
    await _fadeOutCtrl.forward();
    if (!mounted) return;

    // Remove the overlay widget entirely once invisible
    setState(() => _visible = false);
  }

  @override
  void dispose() {
    _globeCtrl.dispose();
    _titleCtrl.dispose();
    _taglineCtrl.dispose();
    _fadeOutCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // The real app sits underneath — StreamBuilder handles routing
        widget.child,

        // Splash overlay — removed from tree once invisible
        if (_visible)
          AnimatedBuilder(
            animation: _fadeOutCtrl,
            builder: (context, child) => Opacity(
              opacity: _overlayFade.value,
              child: child,
            ),
            child: Scaffold(
              backgroundColor: const Color(0xFFFFF8EF),
              body: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32.0),
                  child: Column(
                    children: [
                      const Spacer(flex: 2),

                      // Globe
                      AnimatedBuilder(
                        animation: _globeCtrl,
                        builder: (context, child) => Opacity(
                          opacity: _globeOpacity.value,
                          child: Transform.scale(
                            scale: _globeScale.value,
                            child: child,
                          ),
                        ),
                        child: Image.asset(
                          'assets/images/Globe_with_flying_airplane_icon.png',
                          width: 320,
                          height: 320,
                        ),
                      ),

                      const SizedBox(height: 8),

                      // Title
                      AnimatedBuilder(
                        animation: _titleCtrl,
                        builder: (context, child) => Opacity(
                          opacity: _titleOpacity.value,
                          child: SlideTransition(
                            position: _titleSlide,
                            child: child,
                          ),
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

                      // Tagline
                      AnimatedBuilder(
                        animation: _taglineCtrl,
                        builder: (context, child) => Opacity(
                          opacity: _taglineOpacity.value,
                          child: child,
                        ),
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
            ),
          ),
      ],
    );
  }
}