import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isLoading = false;

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);

    final user = await AuthService.signInWithGoogle();

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (user == null) {
      // User cancelled or error occurred
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign-in cancelled or failed. Please try again.')),
      );
    }
    // If successful, main.dart will automatically navigate away
    // because it listens to authStateChanges
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

              // Logo
              Image.asset(
                'assets/images/Globe_with_flying_airplane_icon.png',
                width: 320,
                height: 320,
              ),

              const SizedBox(height: 8),

              // App name
              Text(
                'My Journey',
                style: GoogleFonts.comfortaa(
                  fontSize: 36,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFFE05A00),
                ),
              ),

              const SizedBox(height: 12),

              // Tagline
              Text(
                'Recording the beauty of life — a personal memoir of your journey',
                textAlign: TextAlign.center,
                style: GoogleFonts.comfortaa(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: const Color(0xFFB07040),
                ),
              ),

              const Spacer(flex: 3),

              // Continue with Google button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleGoogleSignIn,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF5C842),
                    foregroundColor: const Color(0xFF7A3D00),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Color(0xFF7A3D00),
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Google G icon
                            Container(
                              width: 24,
                              height: 24,
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                              child: const Center(
                                child: Text(
                                  'G',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF4285F4),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Continue with Google',
                              style: GoogleFonts.comfortaa(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                ),
              ),

              const Spacer(flex: 1),

              // Privacy note
              Text(
                'By continuing, you agree to our Terms of Service',
                textAlign: TextAlign.center,
                style: GoogleFonts.comfortaa(
                  fontSize: 11,
                  color: const Color(0xFFB07040),
                ),
              ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}