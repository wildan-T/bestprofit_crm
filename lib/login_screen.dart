import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'home_screen.dart';
import 'app_colors.dart'; // Import AppColors

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isLoading = false;
  bool _obscurePassword = true;
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    setState(() => _isLoading = true);
    try {
      await _auth.signInWithEmailAndPassword(email: _emailController.text.trim(), password: _passwordController.text.trim());
      if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeScreen()));
    } on FirebaseAuthException catch (e) {
      if (mounted) _showError('Login Gagal: ${e.message}');
    } catch (e) {
      if (mounted) _showError('Terjadi Kesalahan: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message, style: const TextStyle(color: Colors.white)),
      backgroundColor: const Color(0xFF8B1A1A),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: Stack(
        children: [
          Positioned(top: -60, right: -60, child: Container(width: 250, height: 250, decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.secondary.withOpacity(0.1)))),
          Positioned(bottom: -80, left: -80, child: Container(width: 300, height: 300, decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.primary.withOpacity(0.05)))),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: FadeTransition(
                opacity: _fadeAnim,
                child: SlideTransition(
                  position: _slideAnim,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 60),
                      Center(
                        child: Column(
                          children: [
                            Container(
                              width: 72, height: 72,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: const LinearGradient(colors: [AppColors.primary, Color(0xFF001F50)]),
                                boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.2), blurRadius: 24, spreadRadius: 4)],
                              ),
                              child: const Icon(Icons.show_chart, color: AppColors.secondary, size: 36),
                            ),
                            const SizedBox(height: 18),
                            const Text('BESTPROFIT FUTURES', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.primary, letterSpacing: 3)),
                            const SizedBox(height: 4),
                            const Text('Mobile CRM', style: TextStyle(fontSize: 13, color: AppColors.neutral, letterSpacing: 2)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 52),
                      const Text('Selamat Datang', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: AppColors.primary)),
                      const SizedBox(height: 6),
                      const Text('Masuk ke akun karyawan Anda', style: TextStyle(fontSize: 14, color: AppColors.neutral)),
                      const SizedBox(height: 36),
                      _buildLabel('Email Karyawan'),
                      const SizedBox(height: 8),
                      _buildTextField(controller: _emailController, hintText: 'nama@bestprofit.com', icon: Icons.email_outlined, keyboardType: TextInputType.emailAddress),
                      const SizedBox(height: 20),
                      _buildLabel('Password'),
                      const SizedBox(height: 8),
                      _buildTextField(
                        controller: _passwordController, hintText: '••••••••', icon: Icons.lock_outline, obscureText: _obscurePassword,
                        suffixIcon: IconButton(
                          icon: Icon(_obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: AppColors.neutral, size: 20),
                          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                        ),
                      ),
                      const SizedBox(height: 36),
                      SizedBox(
                        width: double.infinity, height: 54,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _login,
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), padding: EdgeInsets.zero),
                          child: Ink(
                            decoration: BoxDecoration(
                              gradient: _isLoading ? null : const LinearGradient(colors: [AppColors.primary, Color(0xFF001F50)]),
                              color: _isLoading ? AppColors.neutral.withOpacity(0.2) : null,
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 16, offset: const Offset(0, 6))],
                            ),
                            child: Container(
                              alignment: Alignment.center,
                              child: _isLoading
                                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                                  : const Text('MASUK', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 3)),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary, letterSpacing: 1.2));
  }

  Widget _buildTextField({required TextEditingController controller, required String hintText, required IconData icon, TextInputType? keyboardType, bool obscureText = false, Widget? suffixIcon}) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.neutral.withOpacity(0.3), width: 1.5),
      ),
      child: TextField(
        controller: controller, keyboardType: keyboardType, obscureText: obscureText,
        style: const TextStyle(color: AppColors.primary, fontSize: 15, fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(color: AppColors.neutral.withOpacity(0.6), fontSize: 15),
          prefixIcon: Icon(icon, color: AppColors.secondary, size: 20),
          suffixIcon: suffixIcon,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }
}