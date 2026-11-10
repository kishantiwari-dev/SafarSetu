import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../home/home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  late final AnimationController _entranceController;
  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 760),
    )..forward();
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Animation<double> _fade(int start, int end) => CurvedAnimation(
        parent: _entranceController,
        curve: Interval(start / 100, end / 100, curve: Curves.easeOutCubic),
      );

  Widget _enter({required int start, required int end, required Widget child}) {
    final animation = _fade(start, end);
    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, .08), end: Offset.zero)
            .animate(animation),
        child: child,
      ),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _login() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    await Future<void>.delayed(const Duration(milliseconds: 850));
    if (!mounted) return;
    setState(() => _isLoading = false);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
          builder: (_) => HomeScreen(demoEmail: _emailController.text.trim())),
    );
  }

  String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return 'Enter your email address.';
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$').hasMatch(email)) {
      return 'Enter a valid email address.';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Enter your password.';
    if (value.length < 6) return 'Use at least 6 characters.';
    return null;
  }

  InputDecoration _fieldDecoration({
    required String hint,
    required IconData icon,
    Widget? suffix,
  }) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon, size: 20, color: AppColors.secondaryText),
      suffixIcon: suffix,
      filled: true,
      fillColor: AppColors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
      hintStyle: const TextStyle(color: AppColors.secondaryText, fontSize: 14),
      errorStyle: const TextStyle(color: AppColors.error, height: 1.25),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: AppColors.accent, width: 1.4),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: AppColors.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: AppColors.error, width: 1.4),
      ),
    );
  }

  Widget _fieldLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text,
            style: const TextStyle(
              color: AppColors.primaryText,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            )),
      );

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: _SubtleRouteBackdrop()),
          SafeArea(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () => FocusScope.of(context).unfocus(),
              child: LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding:
                      EdgeInsets.fromLTRB(24, 12, 24, 24 + bottomInset * .12),
                  child: ConstrainedBox(
                    constraints:
                        BoxConstraints(minHeight: constraints.maxHeight - 36),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 420),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _enter(
                                start: 0,
                                end: 45,
                                child: Center(
                                  child: Semantics(
                                    image: true,
                                    label: 'SafarSetu — Seat Prediction System',
                                    child: Image.asset(
                                      'assets/images/safarsetu-logo-dark.jpg',
                                      width: 278,
                                      height: 145,
                                      fit: BoxFit.contain,
                                      filterQuality: FilterQuality.high,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),
                              _enter(
                                start: 12,
                                end: 58,
                                child: Column(
                                  children: [
                                    const Text(
                                      'Welcome Back',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: AppColors.primaryText,
                                        fontSize: 28,
                                        height: 1.15,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: -.5,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Plan your journey with confidence.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: AppColors.secondaryText
                                            .withValues(alpha: .95),
                                        fontSize: 15,
                                        letterSpacing: .1,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 31),
                              _enter(
                                start: 22,
                                end: 70,
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    _fieldLabel('Email'),
                                    TextFormField(
                                      controller: _emailController,
                                      focusNode: _emailFocus,
                                      keyboardType: TextInputType.emailAddress,
                                      textInputAction: TextInputAction.next,
                                      autofillHints: const [
                                        AutofillHints.email
                                      ],
                                      autocorrect: false,
                                      enableSuggestions: false,
                                      validator: _validateEmail,
                                      onFieldSubmitted: (_) =>
                                          _passwordFocus.requestFocus(),
                                      decoration: _fieldDecoration(
                                        hint: 'Enter your email',
                                        icon: Icons.alternate_email_rounded,
                                      ),
                                    ),
                                    const SizedBox(height: 19),
                                    _fieldLabel('Password'),
                                    TextFormField(
                                      controller: _passwordController,
                                      focusNode: _passwordFocus,
                                      obscureText: _obscurePassword,
                                      keyboardType:
                                          TextInputType.visiblePassword,
                                      textInputAction: TextInputAction.done,
                                      autofillHints: const [
                                        AutofillHints.password
                                      ],
                                      validator: _validatePassword,
                                      onFieldSubmitted: (_) => _login(),
                                      decoration: _fieldDecoration(
                                        hint: 'Enter your password',
                                        icon: Icons.lock_outline_rounded,
                                        suffix: IconButton(
                                          tooltip: _obscurePassword
                                              ? 'Show password'
                                              : 'Hide password',
                                          onPressed: () => setState(() {
                                            _obscurePassword =
                                                !_obscurePassword;
                                          }),
                                          icon: Icon(
                                            _obscurePassword
                                                ? Icons.visibility_outlined
                                                : Icons.visibility_off_outlined,
                                            color: AppColors.secondaryText,
                                            size: 20,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: () => _showMessage(
                                      'Password recovery will be available soon.'),
                                  style: TextButton.styleFrom(
                                    minimumSize: const Size(48, 44),
                                    foregroundColor: AppColors.accent,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 4),
                                  ),
                                  child: const Text('Forgot Password?',
                                      style: TextStyle(
                                          fontWeight: FontWeight.w600)),
                                ),
                              ),
                              const SizedBox(height: 12),
                              _enter(
                                start: 42,
                                end: 88,
                                child: SizedBox(
                                  height: 54,
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [
                                          AppColors.accent,
                                          AppColors.accentBlue
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: FilledButton(
                                      onPressed: _isLoading ? null : _login,
                                      style: FilledButton.styleFrom(
                                        backgroundColor: Colors.transparent,
                                        disabledBackgroundColor:
                                            Colors.transparent,
                                        shadowColor: Colors.transparent,
                                        foregroundColor: AppColors.background,
                                        disabledForegroundColor: AppColors
                                            .background
                                            .withValues(alpha: .75),
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(16)),
                                      ),
                                      child: AnimatedSwitcher(
                                        duration:
                                            const Duration(milliseconds: 180),
                                        child: _isLoading
                                            ? const SizedBox(
                                                key: ValueKey('loading'),
                                                width: 21,
                                                height: 21,
                                                child:
                                                    CircularProgressIndicator(
                                                  strokeWidth: 2.3,
                                                  color: AppColors.background,
                                                ),
                                              )
                                            : const Text(
                                                'LOGIN',
                                                key: ValueKey('login'),
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  letterSpacing: 1.25,
                                                  fontWeight: FontWeight.w800,
                                                ),
                                              ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 22),
                              _enter(
                                start: 52,
                                end: 100,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Flexible(
                                      child: Text(
                                        "Don't have an account?",
                                        style: TextStyle(
                                            color: AppColors.secondaryText,
                                            fontSize: 14),
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: () => _showMessage(
                                          'Sign up will be available soon.'),
                                      style: TextButton.styleFrom(
                                        foregroundColor: AppColors.accent,
                                        minimumSize: const Size(48, 44),
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8),
                                      ),
                                      child: const Text('Sign Up',
                                          style: TextStyle(
                                              fontWeight: FontWeight.w700)),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SubtleRouteBackdrop extends StatelessWidget {
  const _SubtleRouteBackdrop();

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: CustomPaint(
          painter: _RoutePainter(),
          child: const SizedBox.expand(),
        ),
      );
}

class _RoutePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.accent.withValues(alpha: .045)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final path = Path()
      ..moveTo(size.width * .82, 0)
      ..cubicTo(size.width * .62, size.height * .17, size.width * 1.03,
          size.height * .27, size.width * .80, size.height * .42)
      ..cubicTo(size.width * .62, size.height * .54, size.width * .94,
          size.height * .71, size.width * .76, size.height);
    canvas.drawPath(path, paint);
    final dotPaint = Paint()..color = AppColors.accent.withValues(alpha: .12);
    for (final point in [
      Offset(size.width * .80, size.height * .42),
      Offset(size.width * .82, size.height * .70),
    ]) {
      canvas.drawCircle(point, 3, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
