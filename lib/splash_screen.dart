import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'login_screen.dart';
import 'home_screen.dart';
import 'app_colors.dart'; // Import AppColors

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late AnimationController _logoController;
  late AnimationController _textController;
  late AnimationController _lineController;
  late AnimationController _fadeController;

  late Animation<double> _logoScale;
  late Animation<double> _logoOpacity;
  late Animation<double> _textOpacity;
  late Animation<Offset> _textSlide;
  late Animation<double> _lineWidth;
  late Animation<double> _subtitleOpacity;

  @override
  void initState() {
    super.initState();
    _logoController = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _textController = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _lineController = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _fadeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));

    _logoScale = Tween<double>(begin: 0.4, end: 1.0).animate(CurvedAnimation(parent: _logoController, curve: Curves.elasticOut));
    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _logoController, curve: const Interval(0.0, 0.5)));
    _textOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _textController, curve: Curves.easeOut));
    _textSlide = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(CurvedAnimation(parent: _textController, curve: Curves.easeOut));
    _lineWidth = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _lineController, curve: Curves.easeInOut));
    _subtitleOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeIn));

    _startAnimations();
  }

  void _startAnimations() async {
    await Future.delayed(const Duration(milliseconds: 300));
    _logoController.forward();
    await Future.delayed(const Duration(milliseconds: 600));
    _textController.forward();
    await Future.delayed(const Duration(milliseconds: 300));
    _lineController.forward();
    await Future.delayed(const Duration(milliseconds: 200));
    _fadeController.forward();

    await Future.delayed(const Duration(milliseconds: 1400));
    _navigate();
  }

  void _navigate() {
    final user = FirebaseAuth.instance.currentUser;
    if (mounted) {
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 800),
          pageBuilder: (_, __, ___) => user != null ? const HomeScreen() : const LoginScreen(),
          transitionsBuilder: (_, anim, __, child) => FadeTransition(opacity: anim, child: child),
        ),
      );
    }
  }

  @override
  void dispose() {
    _logoController.dispose();
    _textController.dispose();
    _lineController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: Stack(
        children: [
          Positioned(top: -80, right: -80, child: _GlowCircle(color: AppColors.secondary.withOpacity(0.1), size: 300)),
          Positioned(bottom: -100, left: -60, child: _GlowCircle(color: AppColors.primary.withOpacity(0.05), size: 280)),
          CustomPaint(size: MediaQuery.of(context).size, painter: _GridPainter()),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ScaleTransition(
                  scale: _logoScale,
                  child: FadeTransition(
                    opacity: _logoOpacity,
                    child: Container(
                      width: 100, height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [AppColors.primary, Color(0xFF001F50)],
                        ),
                        boxShadow: [
                          BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 40, spreadRadius: 10),
                        ],
                      ),
                      child: const Icon(Icons.show_chart, size: 52, color: AppColors.secondary),
                    ),
                  ),
                ),
                const SizedBox(height: 36),
                SlideTransition(
                  position: _textSlide,
                  child: FadeTransition(
                    opacity: _textOpacity,
                    child: const Column(
                      children: [
                        Text('BESTPROFIT', style: TextStyle(fontFamily: 'serif', fontSize: 30, fontWeight: FontWeight.w800, color: AppColors.primary, letterSpacing: 6)),
                        Text('FUTURES', style: TextStyle(fontFamily: 'serif', fontSize: 30, fontWeight: FontWeight.w300, color: AppColors.secondary, letterSpacing: 9)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                AnimatedBuilder(
                  animation: _lineWidth,
                  builder: (_, __) => Container(
                    width: 200 * _lineWidth.value, height: 1.5,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(colors: [Colors.transparent, AppColors.secondary, Colors.transparent]),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                FadeTransition(opacity: _subtitleOpacity, child: const Text('Mobile CRM Platform', style: TextStyle(fontSize: 13, color: AppColors.neutral, letterSpacing: 3, fontWeight: FontWeight.w500))),
              ],
            ),
          ),
          Positioned(bottom: 40, left: 0, right: 0, child: FadeTransition(opacity: _subtitleOpacity, child: const Text('v1.0.0', textAlign: TextAlign.center, style: TextStyle(color: AppColors.neutral, fontSize: 12, letterSpacing: 2)))),
        ],
      ),
    );
  }
}

class _GlowCircle extends StatelessWidget {
  final Color color;
  final double size;
  const _GlowCircle({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(width: size, height: size, decoration: BoxDecoration(shape: BoxShape.circle, color: color));
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = AppColors.neutral.withOpacity(0.1)..strokeWidth = 0.5;
    const spacing = 40.0;
    for (double x = 0; x < size.width; x += spacing) canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    for (double y = 0; y < size.height; y += spacing) canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
  }
  @override
  bool shouldRepaint(_) => false;
}