import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:nible/screens/login_screen.dart';
import '../constants/colors.dart';
import 'onboarding_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _gradientController;

  late Animation<double> _pulseAnimation;
  late Animation<double> _gradientShift;

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initApp();
  }

  Future<void> _initApp() async {
    await _initNotifications();
    _initAnimations();
    setState(() {
      _isLoading = false;
    });
  }

  void _initAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _gradientController = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    )..repeat();

    _gradientShift = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _gradientController, curve: Curves.linear),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _gradientController.dispose();
    super.dispose();
  }

  Future<void> _initNotifications() async {
    try {
      await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      await FirebaseMessaging.instance.getToken();
    } catch (_) {}
  }

  void _navigateToOnboarding() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const OnboardingScreen()),
    );
  }

  void _navigateToLogin() {
    Navigator.of(context).pushReplacementNamed('/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors1.backgroundColor,
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [AppColors1.surfaceColor, AppColors1.backgroundColor],
              ),
            ),
          ),
          Positioned.fill(child: CustomPaint(painter: GridPainter())),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SizedBox(
              height: 2,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      AppColors1.glowGreen,
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (!_isLoading)
                  AnimatedBuilder(
                    animation: Listenable.merge([
                      _pulseController,
                      _gradientController,
                    ]),
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _pulseAnimation.value,
                        child: ShaderMask(
                          shaderCallback: (bounds) {
                            return LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: const [
                                AppColors1.primaryGreen,
                                AppColors1.primaryblue,
                                AppColors1.primaryGreen,
                              ],
                              stops: [
                                (_gradientShift.value - 0.2).clamp(0.0, 1.0),
                                _gradientShift.value,
                                (_gradientShift.value + 0.2).clamp(0.0, 1.0),
                              ],
                            ).createShader(bounds);
                          },
                          child: const Text(
                            'N',
                            style: TextStyle(
                              fontSize: 120,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                if (_isLoading)
                  const Text(
                    'N',
                    style: TextStyle(
                      fontSize: 120,
                      fontWeight: FontWeight.w900,
                      color: AppColors1.primaryGreen,
                    ),
                  ),
                const SizedBox(height: 30),
                Text(
                  'Nible',
                  style: TextStyle(
                    fontSize: 56,
                    fontWeight: FontWeight.bold,
                    foreground:
                        Paint()
                          ..shader = const LinearGradient(
                            colors: [
                              AppColors1.primaryGreen,
                              AppColors1.primaryblue,
                              AppColors1.primaryGreen,
                            ],
                          ).createShader(const Rect.fromLTWH(0, 0, 200, 70)),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Food at your comfort',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    color: AppColors1.textSecondary,
                  ),
                ),
                const SizedBox(height: 40),
                SizedBox(
                  width: 134,
                  height: 5,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppColors1.subtleGlow,
                      borderRadius: const BorderRadius.all(Radius.circular(3)),
                    ),
                  ),
                ),
                const SizedBox(height: 40),
                if (!_isLoading) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _navigateToOnboarding,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors1.primaryGreen,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        child: const Text(
                          'Get Started',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: _navigateToLogin,
                    child: const Text(
                      'Already have an account? Sign In',
                      style: TextStyle(
                        color: AppColors1.primaryGreen,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = AppColors1.primaryGreen.withOpacity(0.03)
          ..strokeWidth = 1;

    for (double i = 0; i < size.width; i += 50) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }
    for (double j = 0; j < size.height; j += 50) {
      canvas.drawLine(Offset(0, j), Offset(size.width, j), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
