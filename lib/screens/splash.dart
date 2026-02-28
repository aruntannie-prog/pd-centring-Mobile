import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/store.dart';
import '../theme/app_theme.dart';

class SplashScreen extends StatefulWidget {
  final VoidCallback onDone;
  const SplashScreen({super.key, required this.onDone});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _logoCtrl, _fadeCtrl, _barCtrl, _glowCtrl;
  late Animation<double> _logoScale,
      _logoOpacity,
      _fadeIn,
      _barWidth,
      _glowPulse;
  bool _animDone = false;
  bool _navigated = false;
  AppStore? _store;

  @override
  void initState() {
    super.initState();

    _logoCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900));
    _logoScale = CurvedAnimation(parent: _logoCtrl, curve: Curves.elasticOut)
        .drive(Tween(begin: .65, end: 1.0));
    _logoOpacity = CurvedAnimation(parent: _logoCtrl, curve: Curves.easeOut)
        .drive(Tween(begin: 0.0, end: 1.0));

    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900));
    _fadeIn = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut)
        .drive(Tween(begin: 0.0, end: 1.0));

    _barCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 3200));
    _barWidth = CurvedAnimation(parent: _barCtrl, curve: Curves.easeInOut)
        .drive(Tween(begin: 0.0, end: 1.0));

    _glowCtrl =
        AnimationController(vsync: this, duration: const Duration(seconds: 3))
          ..repeat(reverse: true);
    _glowPulse = CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut)
        .drive(Tween(begin: .7, end: 1.0));

    // Warm up the font immediately
    GoogleFonts.pinyonScript().fontSize;

    // Start ambient animations immediately
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) _logoCtrl.forward();
    });
    Future.delayed(
        const Duration(milliseconds: 950), () => _fadeCtrl.forward());
    Future.delayed(
        const Duration(milliseconds: 1500), () => _barCtrl.forward());

    // Total animation time drastically reduced to ensure fast startup (was 4000ms).
    // The splash now navigates instantly after the core pulse (2500ms).
    Future.delayed(const Duration(milliseconds: 2500), () {
      if (mounted) {
        _animDone = true;
        _checkFinish();
      }
    });

    // Safety net: never freeze longer than 15 seconds
    Future.delayed(const Duration(seconds: 15), () {
      if (mounted && !_navigated) {
        _navigated = true;
        widget.onDone();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Subscribe to AppStore so we re-check whenever isReady flips
    final store = context.watch<AppStore>();
    if (_store != store) {
      _store = store;
    }
    _checkFinish();
  }

  void _checkFinish() {
    if (_navigated) return;
    final isReady = context.read<AppStore>().isReady;
    if (_animDone && isReady) {
      _navigated = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onDone();
      });
    }
  }

  @override
  void dispose() {
    _logoCtrl.dispose();
    _fadeCtrl.dispose();
    _barCtrl.dispose();
    _glowCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: colors.surface,
      body: Stack(children: [
        // Subtle ambient glow
        Positioned(
          top: MediaQuery.of(context).size.height * .2,
          left: 0,
          right: 0,
          child: Center(
              child: AnimatedBuilder(
            animation: _glowPulse,
            builder: (_, __) => Transform.scale(
              scale: _glowPulse.value,
              child: Container(
                width: 380,
                height: 380,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [
                    colors.brand
                        .withOpacity(isDark ? 0.15 : 0.08 * _glowPulse.value),
                    colors.brand
                        .withOpacity(isDark ? 0.05 : 0.03 * _glowPulse.value),
                    Colors.transparent,
                  ]),
                ),
              ),
            ),
          )),
        ),
        // Scan lines (subtle texture)
        Positioned.fill(
            child: CustomPaint(
                painter: _ScanLinePainter(colors.textMuted.withOpacity(0.03)))),
        // Main content
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo
                AnimatedBuilder(
                  animation: Listenable.merge([_logoScale, _logoOpacity]),
                  builder: (_, __) => Opacity(
                    opacity: _logoOpacity.value,
                    child: Transform.scale(
                      scale: _logoScale.value,
                      child: Container(
                        child: Text(
                          'PD',
                          style: GoogleFonts.pinyonScript(
                              fontSize: 120,
                              fontWeight: FontWeight.w400,
                              color: const Color(0xFFFF0000),
                              shadows: [
                                Shadow(
                                    color: Colors.black.withOpacity(0.5),
                                    offset: const Offset(0, 8),
                                    blurRadius: 20),
                                Shadow(
                                    color: const Color(0xFFFF0000)
                                        .withOpacity(0.4),
                                    offset: const Offset(0, 0),
                                    blurRadius: 40),
                                Shadow(
                                    color: const Color(0xFFFF0000)
                                        .withOpacity(0.2),
                                    offset: const Offset(0, 0),
                                    blurRadius: 60),
                              ]),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                FadeTransition(
                    opacity: _fadeIn,
                    child: Column(children: [
                      RichText(
                          text: TextSpan(children: [
                        TextSpan(
                            text: 'PD ',
                            style: GoogleFonts.playfairDisplay(
                                fontSize: 36,
                                fontWeight: FontWeight.w900,
                                color: colors.textMain)),
                        TextSpan(
                            text: 'Centring',
                            style: GoogleFonts.playfairDisplay(
                                fontSize: 36,
                                fontWeight: FontWeight.w900,
                                color: colors.brand,
                                fontStyle: FontStyle.italic)),
                      ])),
                      const SizedBox(height: 8),
                      Text('SHUTTERING RENTAL · SOUTH CHENNAI',
                          style: GoogleFonts.plusJakartaSans(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                              color: colors.textMuted,
                              letterSpacing: 3.5)),
                    ])),
                const SizedBox(height: 48),
                // Stats row
                FadeTransition(
                  opacity: _fadeIn,
                  child: Container(
                    decoration: BoxDecoration(
                      color:
                          colors.surfaceVariant.withOpacity(isDark ? 0.3 : 0.6),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: colors.border, width: 0.5),
                      boxShadow: [
                        BoxShadow(
                            color: colors.glow,
                            blurRadius: 16,
                            offset: const Offset(0, 4)),
                      ],
                    ),
                    child: Row(children: [
                      _stat('4,950+', 'Bills', colors),
                      _stat('985', 'Clients', colors),
                      _stat('#6051', 'Latest', colors, last: true),
                    ]),
                  ),
                ),
                const SizedBox(height: 40),
                // Loading bar
                FadeTransition(
                  opacity: _fadeIn,
                  child: SizedBox(
                    width: 175,
                    child: Column(children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: Container(
                          height: 3,
                          color: colors.border.withOpacity(.5),
                          child: AnimatedBuilder(
                            animation: _barWidth,
                            builder: (_, __) => FractionallySizedBox(
                              alignment: Alignment.centerLeft,
                              widthFactor: _barWidth.value,
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                      colors: [colors.brand, colors.teal]),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text('LOADING COMPANY DATA...',
                          style: GoogleFonts.plusJakartaSans(
                              fontSize: 8.5,
                              fontWeight: FontWeight.w800,
                              color: colors.textMuted,
                              letterSpacing: 2.5)),
                    ]),
                  ),
                ),
              ],
            ),
          ),
        ),
      ]),
    );
  }

  Widget _stat(String v, String l, AppColors colors, {bool last = false}) =>
      Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            border: last
                ? null
                : Border(right: BorderSide(color: colors.border, width: 0.5)),
          ),
          child: Column(children: [
            Text(v,
                style: GoogleFonts.playfairDisplay(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: colors.textMain)),
            const SizedBox(height: 4),
            Text(l.toUpperCase(),
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 8.5,
                    fontWeight: FontWeight.w800,
                    color: colors.textSub,
                    letterSpacing: 2)),
          ]),
        ),
      );
}

class _ScanLinePainter extends CustomPainter {
  final Color color;
  _ScanLinePainter(this.color);
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    for (double y = 0; y < size.height; y += 4) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ScanLinePainter oldDelegate) =>
      oldDelegate.color != color;
}
