import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _error;

  void _login() async {
    final email = _emailController.text.trim();
    final pwd = _passwordController.text;

    if (email.isEmpty || pwd.isEmpty) {
      if (mounted) setState(() => _error = 'Please enter email and password');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    final error = await AuthService.login(email, pwd);

    if (mounted) {
      setState(() {
        _isLoading = false;
        _error = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      backgroundColor: colors.surface,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + bottomInset),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // App Icon Logo
                    Center(
                      child: Image.asset(
                        'assets/logo.png',
                        width: 96,
                        height: 96,
                      ),
                    ),
                    const SizedBox(height: 32),
                    
                    // Welcome Texts
                    Text(
                      'Welcome Back',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 36,
                        fontWeight: FontWeight.w900,
                        color: colors.textMain,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Sign in to PD Centring\nBilling Manager',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        color: colors.textMuted,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 48),

                    // Login Card
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF141A28) : Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: colors.border, width: 0.5),
                        boxShadow: [
                          BoxShadow(
                            color: colors.glow.withOpacity(isDark ? 0.1 : 0.05),
                            blurRadius: 32,
                            offset: const Offset(0, 16),
                          )
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Error Banner
                          if (_error != null) ...[
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFF4D4D).withOpacity(isDark ? 0.15 : 0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFFF4D4D).withOpacity(0.3)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.error_outline_rounded, size: 18, color: Color(0xFFFF4D4D)),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _error!,
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: isDark ? const Color(0xFFFF8080) : const Color(0xFFD62828),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],

                          // Email Field
                          Text(
                            'Email Address',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: colors.textSub,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            style: GoogleFonts.plusJakartaSans(fontSize: 14, color: colors.textMain),
                            decoration: InputDecoration(
                              hintText: 'hello@example.com',
                              hintStyle: GoogleFonts.plusJakartaSans(color: colors.textMuted.withOpacity(0.5)),
                              filled: false,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide(color: colors.border),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide(color: colors.border),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide(color: colors.brand, width: 1.5),
                              ),
                            ),
                            onSubmitted: (_) => _login(),
                          ),
                          const SizedBox(height: 20),

                          // Password Field
                          Text(
                            'Password',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: colors.textSub,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _passwordController,
                            obscureText: true,
                            style: GoogleFonts.plusJakartaSans(fontSize: 14, color: colors.textMain),
                            decoration: InputDecoration(
                              hintText: '••••••••',
                              hintStyle: GoogleFonts.plusJakartaSans(color: colors.textMuted.withOpacity(0.5)),
                              filled: false,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide(color: colors.border),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide(color: colors.border),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide(color: colors.brand, width: 1.5),
                              ),
                            ),
                            onSubmitted: (_) => _login(),
                          ),
                          const SizedBox(height: 32),

                          // Sign In Button
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _login,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: colors.brand,
                                foregroundColor: isDark ? colors.surface : Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 18),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                elevation: 8,
                                shadowColor: colors.brand.withOpacity(0.5),
                                disabledBackgroundColor: colors.surfaceVariant,
                              ),
                              child: _isLoading 
                                  ? SizedBox(
                                      width: 24, 
                                      height: 24, 
                                      child: CircularProgressIndicator(color: isDark ? colors.surface : Colors.white, strokeWidth: 2.5)
                                    )
                                  : Text(
                                      'Sign In',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
    );
  }
}
