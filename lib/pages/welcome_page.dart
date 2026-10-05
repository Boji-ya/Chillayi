// lib/pages/welcome_page.dart
import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:provider/provider.dart';
import '../services/auth_service.dart';

// ── Welcome Page ──────────────────────────────────────────────────────────────
class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key});
  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage>
    with TickerProviderStateMixin {
  late final AnimationController _spinCtrl;
  late final AnimationController _floatCtrl;
  late final Animation<double> _floatAnim;

  @override
  void initState() {
    super.initState();
    _spinCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    )..repeat();

    _floatCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3800),
    )..repeat(reverse: true);

    _floatAnim = Tween<double>(begin: 0, end: -7).animate(
      CurvedAnimation(parent: _floatCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _spinCtrl.dispose();
    _floatCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('images/welcomepage.jpg'),
            fit: BoxFit.cover,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 26),
            child: Column(
              children: [
                const SizedBox(height: 18),

                // ── Top bar ─────────────────────────────────────
                const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Chiayi Travelling App',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF0F2D52),
                              fontFamily: 'Georgia',
                            )),
                      ],
                    ),
                    Spacer(),
                  ],
                ),

                const SizedBox(height: 26),

                // ── Spinning badge ──────────────────────────────
                AnimatedBuilder(
                  animation: _floatAnim,
                  builder: (_, child) => Transform.translate(
                    offset: Offset(0, _floatAnim.value),
                    child: child,
                  ),
                  child: SizedBox(
                    width: 300, height: 300,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Rotating ring
                        AnimatedBuilder(
                          animation: _spinCtrl,
                          builder: (_, __) => Transform.rotate(
                            angle: _spinCtrl.value * 2 * math.pi,
                            child: CustomPaint(
                              size: const Size(300, 300),
                              painter: _RingPainter(),
                            ),
                          ),
                        ),
                        // White circle backing
                        Container(
                          width: 196, height: 196,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                            border: Border.all(
                                color: Colors.white, width: 3),
                          ),
                        ),
                        // Turkey image
                        ClipOval(
                          child: Image.asset(
                            'images/turkey.png',
                            width: 180,
                            height: 180,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 14),

                // ── Wordmark ────────────────────────────────────
                const Text('Chillayi',
                    style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF0F2D52),
                      letterSpacing: 2,
                      fontFamily: 'Georgia',
                    )),
                Container(
                  width: 70, height: 4,
                  decoration: BoxDecoration(
                      color: const Color(0xFF1A5FA8),
                      borderRadius: BorderRadius.circular(2)),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(3,
                          (_) => Container(
                        width: 5, height: 5, margin: const EdgeInsets.symmetric(horizontal: 3),
                        decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFF1A5FA8).withOpacity(0.4)),
                      )),
                ),

                const Spacer(),

                // ── Buttons ─────────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const LoginPage())),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F2D52),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Text('Login',
                        style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1,
                            fontFamily: 'Georgia')),
                  ),
                ),
                const SizedBox(height: 13),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const SignUpPage())),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF0F2D52),
                      side: const BorderSide(
                          color: Color(0xFF0F2D52), width: 2.5),
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Text('Sign up',
                        style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1,
                            fontFamily: 'Georgia')),
                  ),
                ),
                const SizedBox(height: 44),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Ring painter ──────────────────────────────────────────────────────────────
class _RingPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    canvas.drawCircle(Offset(cx, cy), 149,
        Paint()..color = const Color(0xFF0F2D52));
    canvas.drawCircle(Offset(cx, cy), 139,
        Paint()..color = const Color(0xFF79AAE7));
    canvas.drawCircle(Offset(cx, cy), 110,
        Paint()..color = const Color(0xFF0F2D52));

    _drawDots(canvas, cx, cy, 106);
    const text = 'CHILLAYI ✦ CHILLAYI ✦ CHILLAYI ✦ ';
    _drawCircularText(canvas, cx, cy, text, 123);
  }

  void _drawDots(Canvas canvas, double cx, double cy, double r) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.3)
      ..style = PaintingStyle.fill;
    const count = 60;
    for (int i = 0; i < count; i++) {
      final angle = 2 * math.pi * i / count;
      canvas.drawCircle(
        Offset(cx + r * math.cos(angle), cy + r * math.sin(angle)),
        1.8,
        paint,
      );
    }
  }

  void _drawCircularText(
      Canvas canvas, double cx, double cy, String text, double r) {
    final charCount = text.length;
    final angleStep = 2 * math.pi / charCount;
    const startAngle = -math.pi / 2;

    for (int i = 0; i < charCount; i++) {
      final angle = startAngle + i * angleStep;
      final x = cx + r * math.cos(angle);
      final y = cy + r * math.sin(angle);

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(angle + math.pi / 2);

      final tp = TextPainter(
        text: TextSpan(
          text: text[i],
          style: const TextStyle(
            fontSize: 15.5,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            letterSpacing: 0,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

// ── Login Page ────────────────────────────────────────────────────────────────
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage>
    with TickerProviderStateMixin {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _emailFocus = FocusNode();
  final _passFocus = FocusNode();

  bool _loading = false;
  bool _obscure = true;
  bool _eyesClosed = false;
  Offset _lookTarget = const Offset(0, 0);

  final GlobalKey _turkeyKey = GlobalKey();

  late final AnimationController _wobbleCtrl;
  late final Animation<double> _wobbleAnim;

  @override
  void initState() {
    super.initState();
    _wobbleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )
      ..repeat(reverse: true);
    _wobbleAnim = Tween<double>(begin: -0.03, end: 0.03).animate(
      CurvedAnimation(parent: _wobbleCtrl, curve: Curves.easeInOut),
    );
    _passFocus.addListener(() {
      setState(() => _eyesClosed = _passFocus.hasFocus);
    });
    _emailFocus.addListener(() {
      if (_emailFocus.hasFocus) {
        setState(() => _lookTarget = const Offset(-0.3, 0.4));
      }
    });
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _emailFocus.dispose();
    _passFocus.dispose();
    _wobbleCtrl.dispose();
    super.dispose();
  }

  void _showForgotPassword(BuildContext context) {
    final emailCtrl = TextEditingController(text: _emailCtrl.text.trim());
    bool sending = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => StatefulBuilder(
        builder: (ctx, setS) => Container(
          margin: EdgeInsets.fromLTRB(
              16, 0, 16, MediaQuery.of(sheetCtx).viewInsets.bottom + 24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFF0F2D52).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.lock_reset, color: Color(0xFF0F2D52), size: 20),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('忘記密碼', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F2D52))),
                  Text('輸入 Email，我們將寄送重設連結', style: TextStyle(fontSize: 12, color: Colors.grey)),
                ]),
              ),
            ]),
            const SizedBox(height: 20),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF5F8FF),
                borderRadius: BorderRadius.circular(50),
                border: Border.all(color: const Color(0xFFCCDDEE)),
              ),
              child: TextField(
                controller: emailCtrl,
                keyboardType: TextInputType.emailAddress,
                style: const TextStyle(fontSize: 14, color: Color(0xFF0F2D52)),
                decoration: InputDecoration(
                  hintText: '請輸入您的 Email',
                  hintStyle: const TextStyle(color: Color(0xFFAAC4DC)),
                  prefixIcon: const Icon(Icons.mail_outline, color: Color(0xFF8AAAC8)),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(50), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                ),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: sending ? null : () async {
                  if (emailCtrl.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('請輸入 Email')));
                    return;
                  }
                  setS(() => sending = true);
                  final error = await context.read<AuthService>().sendPasswordResetEmail(emailCtrl.text);
                  if (!ctx.mounted) return;
                  Navigator.pop(sheetCtx);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(error ?? '重設連結已寄出，請檢查您的信箱 📧'),
                    backgroundColor: error == null ? const Color(0xFF0F2D52) : Colors.red,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ));
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F2D52),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: const StadiumBorder(),
                ),
                child: sending
                    ? const SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('寄送重設連結', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Future<void> _login() async {
    setState(() => _loading = true);
    final error = await context.read<AuthService>().signIn(
        email: _emailCtrl.text, password: _passCtrl.text);
    if (!mounted) return;
    setState(() => _loading = false);
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error), backgroundColor: Colors.red));
    } else {
      Navigator.pushNamedAndRemoveUntil(context, '/home', (_) => false);
    }
  }

  void _onTapDown(TapDownDetails details) {
    final box = _turkeyKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final turkeyPos = box.localToGlobal(Offset(
      box.size.width / 2,
      box.size.height * 0.42,
    ));
    final tap = details.globalPosition;
    final dx = (tap.dx - turkeyPos.dx) / 120;
    final dy = (tap.dy - turkeyPos.dy) / 120;
    setState(() {
      _lookTarget = Offset(dx.clamp(-1, 1), dy.clamp(-1, 1));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFDFF0FF),
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          // ─── 1. TRUE FULL SCREEN BACKGROUND IMAGE ───────────────────
          Positioned.fill(
            child: Image.asset(
              'images/welcomepage.jpg',
              fit: BoxFit.cover,
            ),
          ),

          // ─── 2. INTERACTIVE CONTENT LAYER ───────────────────────────
          Positioned.fill(
            child: GestureDetector(
              onTapDown: _onTapDown,
              child: SafeArea(
                top:false,
                bottom: false,
                // Allows content/scroll area to flush to the very bottom
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        alignment: Alignment.topCenter,
                        children: [
                          Container(
                            width: double.infinity,
                            height: 370,
                            decoration: const BoxDecoration(
                              color: Color(0xFF0F2D52),
                              // Your top dark blue curved header
                              borderRadius: BorderRadius.only(
                                bottomLeft: Radius.elliptical(200, 80),
                                bottomRight: Radius.elliptical(200, 80),
                              ),
                            ),
                          ),

                          const Positioned(
                            top: 75,
                            child: Column(
                              children: [
                                Text(
                                  'Welcome,',
                                  style: TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                    fontFamily: 'Georgia',
                                  ),
                                ),
                                Text(
                                  "let's get signed in!",
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white70,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          Positioned(
                            bottom: -30,
                            child: AnimatedBuilder(
                              animation: _wobbleAnim,
                              builder: (_, child) =>
                                  Transform.rotate(
                                    angle: _wobbleAnim.value,
                                    alignment: Alignment.bottomCenter,
                                    child: child,
                                  ),
                              child: SizedBox(
                                key: _turkeyKey,
                                width: 300,
                                height: 280,
                                child: CustomPaint(
                                  painter: _TurkeyCharacterPainter(
                                    lookTarget: _lookTarget,
                                    eyesClosed: _eyesClosed,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 48),

                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 28),
                        child: Column(
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(50),
                              ),
                              child: TextField(
                                controller: _emailCtrl,
                                focusNode: _emailFocus,
                                keyboardType: TextInputType.emailAddress,
                                onTap: () =>
                                    setState(
                                            () =>
                                        _lookTarget = const Offset(-0.3, 0.4)),
                                style: const TextStyle(
                                    fontSize: 14, color: Color(0xFF0F2D52)),
                                decoration: InputDecoration(
                                  hintText: 'Email',
                                  hintStyle: const TextStyle(
                                      color: Color(0xFFAAC4DC)),
                                  prefixIcon: const Icon(Icons.mail_outline,
                                      color: Color(0xFF8AAAC8)),
                                  border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(50),
                                      borderSide: BorderSide.none),
                                  contentPadding: const EdgeInsets.symmetric(
                                      vertical: 14, horizontal: 20),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(50),
                              ),
                              child: TextField(
                                controller: _passCtrl,
                                focusNode: _passFocus,
                                obscureText: _obscure,
                                style: const TextStyle(
                                    fontSize: 14, color: Color(0xFF0F2D52)),
                                decoration: InputDecoration(
                                  hintText: 'Password',
                                  hintStyle: const TextStyle(
                                      color: Color(0xFFAAC4DC)),
                                  prefixIcon: const Icon(Icons.lock_outline,
                                      color: Color(0xFF8AAAC8)),
                                  suffixIcon: TextButton(
                                    onPressed: () =>
                                        setState(() => _obscure = !_obscure),
                                    child: Text(
                                      _obscure ? '顯示密碼' : '隱藏',
                                      style: const TextStyle(
                                          color: Color(0xFF1A5FA8),
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700),
                                    ),
                                  ),
                                  border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(50),
                                      borderSide: BorderSide.none),
                                  contentPadding: const EdgeInsets.symmetric(
                                      vertical: 14, horizontal: 20),
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            SizedBox(
                              width: double.infinity,
                              child: _loading
                                  ? const Center(
                                  child: CircularProgressIndicator(
                                      color: Color(0xFF0F2D52)))
                                  : ElevatedButton(
                                onPressed: _login,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF0F2D52),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 15),
                                  shape: const StadiumBorder(),
                                ),
                                child: const Text('登入',
                                    style: TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 1,
                                        fontFamily: 'Georgia')),
                              ),
                            ),
                            const SizedBox(height: 8),
                            // 忘記密碼
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: () => _showForgotPassword(context),
                                child: const Text(
                                  '忘記密碼？',
                                  style: TextStyle(
                                    color: Color(0xFF1A5FA8),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextButton(
                              onPressed: () =>
                                  Navigator.pushReplacement(context,
                                      MaterialPageRoute(
                                          builder: (_) => const SignUpPage())),
                              child: RichText(
                                text: const TextSpan(
                                  text: '還沒有帳號？',
                                  style: TextStyle(
                                      color: Color(0xFF2A5080),
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13),
                                  children: [
                                    TextSpan(
                                      text: '立即註冊',
                                      style: TextStyle(
                                          color: Color(0xFF1A5FA8)),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 32),
                          ],
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
}


// ── Turkey character painter ──────────────────────────────────────────────────
class _TurkeyCharacterPainter extends CustomPainter {
  final Offset lookTarget;
  final bool eyesClosed;

  const _TurkeyCharacterPainter({
    required this.lookTarget,
    required this.eyesClosed,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;

    final featherData = [
      (-60.0, cx - 60, 148.0),
      (-40.0, cx - 35, 118.0),
      (-18.0, cx - 10, 105.0),
      (  0.0, cx,      100.0),
      ( 18.0, cx + 10, 105.0),
      ( 40.0, cx + 35, 118.0),
      ( 60.0, cx + 60, 148.0),
    ];
    for (final (angleDeg, fx, fy) in featherData) {
      final angle = angleDeg * (math.pi / 180);
      canvas.save();
      canvas.translate(fx, fy);
      canvas.rotate(angle);
      canvas.drawOval(
        Rect.fromCenter(center: const Offset(0, 0), width: 76, height: 44),
        Paint()..color = const Color(0xFF8B4513),
      );
      canvas.drawOval(
        Rect.fromCenter(center: const Offset(0, 0), width: 60, height: 32),
        Paint()..color = const Color(0xFFA0522D),
      );
      canvas.restore();
    }

    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, 195), width: 144, height: 110),
      Paint()..color = const Color(0xFFA0522D),
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, 195), width: 120, height: 88),
      Paint()..color = const Color(0xFFc27840),
    );

    _drawWingOval(canvas, cx - 58, 188, -18);
    _drawWingOval(canvas, cx + 58, 188,  18);

    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, 152), width: 48, height: 44),
      Paint()..color = const Color(0xFFc27840),
    );

    canvas.drawCircle(Offset(cx, 118), 46,
        Paint()..color = const Color(0xFFc27840));
    canvas.drawCircle(Offset(cx, 118), 42,
        Paint()..color = const Color(0xFFd4895a));

    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx - 16, 134), width: 18, height: 40),
      Paint()..color = const Color(0xFFc0392b),
    );
    canvas.drawCircle(Offset(cx - 16, 153), 9,
        Paint()..color = const Color(0xFFc0392b));

    final beak = Path()
      ..moveTo(cx - 12, 124)
      ..lineTo(cx - 30, 132)
      ..lineTo(cx - 12, 136)
      ..close();
    canvas.drawPath(beak, Paint()..color = const Color(0xFFe8c050));
    final beakTop = Path()
      ..moveTo(cx - 12, 124)
      ..lineTo(cx - 30, 132)
      ..lineTo(cx - 12, 130)
      ..close();
    canvas.drawPath(beakTop, Paint()..color = const Color(0xFFd4a830));

    for (final bx in [cx - 28.0, cx + 28.0]) {
      canvas.drawOval(
        Rect.fromCenter(center: Offset(bx, 122), width: 20, height: 14),
        Paint()..color = const Color(0xFFe87060).withOpacity(0.4),
      );
    }

    const eyeRadius   = 13.0;
    const pupilRadius = 5.5;
    const maxShift    = 4.0;
    final leftEye  = Offset(cx - 14, 108);
    final rightEye = Offset(cx + 18, 108);
    final pdx = lookTarget.dx * maxShift;
    final pdy = lookTarget.dy * maxShift;

    if (eyesClosed) {
      final p = Paint()
        ..color = const Color(0xFF5a3010)
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      for (final ec in [leftEye, rightEye]) {
        canvas.drawPath(
          Path()
            ..moveTo(ec.dx - eyeRadius + 2, ec.dy)
            ..quadraticBezierTo(ec.dx, ec.dy - 8, ec.dx + eyeRadius - 2, ec.dy),
          p,
        );
        for (int l = -1; l <= 1; l++) {
          canvas.drawLine(
            Offset(ec.dx + l * 5, ec.dy - 2),
            Offset(ec.dx + l * 5, ec.dy - 8),
            p..strokeWidth = 2,
          );
        }
      }
    } else {
      for (final ec in [leftEye, rightEye]) {
        canvas.drawCircle(ec, eyeRadius, Paint()..color = Colors.white);
        canvas.drawCircle(
          Offset(ec.dx + pdx, ec.dy + pdy),
          pupilRadius,
          Paint()..color = const Color(0xFF1a1a1a),
        );
        canvas.drawCircle(
          Offset(ec.dx + pdx + 2, ec.dy + pdy - 3),
          2.5,
          Paint()..color = Colors.white,
        );
      }
    }
  }

  void _drawWingOval(Canvas canvas, double x, double y, double angleDeg) {
    final angle = angleDeg * (math.pi / 180);
    canvas.save();
    canvas.translate(x, y);
    canvas.rotate(angle);
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(0, 0), width: 44, height: 76),
      Paint()..color = const Color(0xFF8B4513),
    );
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(0, 0), width: 32, height: 56),
      Paint()..color = const Color(0xFFA0522D),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_TurkeyCharacterPainter old) =>
      old.lookTarget != lookTarget || old.eyesClosed != eyesClosed;
}

// ── Sign Up Page ──────────────────────────────────────────────────────────────
class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});
  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage>
    with SingleTickerProviderStateMixin {
  final _nameCtrl  = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl  = TextEditingController();
  final _passFocus = FocusNode();

  bool _loading    = false;
  bool _obscure    = true;
  bool _eyesClosed = false;
  Offset _lookTarget = const Offset(0, 0);

  late final AnimationController _wobbleCtrl;
  late final Animation<double>   _wobbleAnim;

  @override
  void initState() {
    super.initState();
    _wobbleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..repeat(reverse: true);
    _wobbleAnim = Tween<double>(begin: -0.03, end: 0.03).animate(
      CurvedAnimation(parent: _wobbleCtrl, curve: Curves.easeInOut),
    );
    _passFocus.addListener(() {
      setState(() => _eyesClosed = _passFocus.hasFocus);
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _passFocus.dispose();
    _wobbleCtrl.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    if (_nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('請輸入使用者名稱')));
      return;
    }
    setState(() => _loading = true);
    final error = await context.read<AuthService>().signUp(
        username: _nameCtrl.text,
        email: _emailCtrl.text,
        password: _passCtrl.text);
    if (!mounted) return;
    setState(() => _loading = false);
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error), backgroundColor: Colors.red));
    } else {
      Navigator.pushNamedAndRemoveUntil(context, '/home', (_) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFDFF0FF),
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          // ─── 1. TRUE FULL SCREEN BACKGROUND IMAGE ───────────────────
          Positioned.fill(
            child: Image.asset(
              'images/welcomepage.jpg',
              fit: BoxFit.cover,
            ),
          ),

          // ─── 2. INTERACTIVE CONTENT LAYER ───────────────────────────
          Positioned.fill(
            child: GestureDetector(
              onTapDown: (_) => setState(() => _lookTarget = const Offset(0.3, 0.4)),
              child: SafeArea(
                top: false,
                bottom: false,
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        alignment: Alignment.topCenter,
                        children: [
                          Container(
                            width: double.infinity,
                            height: 370,
                            decoration: const BoxDecoration(
                              color: Color(0xFF0F2D52),
                              borderRadius: BorderRadius.only(
                                bottomLeft:  Radius.elliptical(200, 80),
                                bottomRight: Radius.elliptical(200, 80),
                              ),
                            ),
                          ),
                          const Positioned(
                            top: 75,
                            child: Column(
                              children: [
                                Text('Join us,',
                                    style: TextStyle(
                                      fontSize: 32,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                      fontFamily: 'Georgia',
                                    )),
                                Text('create your account!',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white70,
                                    )),
                              ],
                            ),
                          ),
                          Positioned(
                            bottom: -30,
                            child: AnimatedBuilder(
                              animation: _wobbleAnim,
                              builder: (_, child) => Transform.rotate(
                                angle: _wobbleAnim.value,
                                alignment: Alignment.bottomCenter,
                                child: child,
                              ),
                              child: SizedBox(
                                width: 300,
                                height: 280,
                                child: CustomPaint(
                                  painter: _TurkeyCharacterPainter(
                                    lookTarget: _lookTarget,
                                    eyesClosed: _eyesClosed,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 48),

                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 28),
                        child: Column(
                          children: [
                            // Username
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(50),
                              ),
                              child: TextField(
                                controller: _nameCtrl,
                                onTap: () => setState(
                                        () => _lookTarget = const Offset(-0.3, 0.4)),
                                style: const TextStyle(
                                    fontSize: 14, color: Color(0xFF0F2D52)),
                                decoration: InputDecoration(
                                  hintText: '使用者名稱',
                                  hintStyle: const TextStyle(color: Color(0xFFAAC4DC)),
                                  prefixIcon: const Icon(Icons.person_outline,
                                      color: Color(0xFF8AAAC8)),
                                  border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(50),
                                      borderSide: BorderSide.none),
                                  contentPadding: const EdgeInsets.symmetric(
                                      vertical: 14, horizontal: 20),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            // Email
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(50),
                              ),
                              child: TextField(
                                controller: _emailCtrl,
                                keyboardType: TextInputType.emailAddress,
                                onTap: () => setState(
                                        () => _lookTarget = const Offset(-0.3, 0.4)),
                                style: const TextStyle(
                                    fontSize: 14, color: Color(0xFF0F2D52)),
                                decoration: InputDecoration(
                                  hintText: 'Email',
                                  hintStyle: const TextStyle(color: Color(0xFFAAC4DC)),
                                  prefixIcon: const Icon(Icons.mail_outline,
                                      color: Color(0xFF8AAAC8)),
                                  border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(50),
                                      borderSide: BorderSide.none),
                                  contentPadding: const EdgeInsets.symmetric(
                                      vertical: 14, horizontal: 20),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            // Password — eyes close
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(50),
                              ),
                              child: TextField(
                                controller: _passCtrl,
                                focusNode:  _passFocus,
                                obscureText: _obscure,
                                style: const TextStyle(
                                    fontSize: 14, color: Color(0xFF0F2D52)),
                                decoration: InputDecoration(
                                  hintText: '密碼（至少6碼）',
                                  hintStyle: const TextStyle(color: Color(0xFFAAC4DC)),
                                  prefixIcon: const Icon(Icons.lock_outline,
                                      color: Color(0xFF8AAAC8)),
                                  suffixIcon: TextButton(
                                    onPressed: () =>
                                        setState(() => _obscure = !_obscure),
                                    child: Text(
                                      _obscure ? '顯示密碼' : '隱藏',
                                      style: const TextStyle(
                                          color: Color(0xFF1A5FA8),
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700),
                                    ),
                                  ),
                                  border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(50),
                                      borderSide: BorderSide.none),
                                  contentPadding: const EdgeInsets.symmetric(
                                      vertical: 14, horizontal: 20),
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            SizedBox(
                              width: double.infinity,
                              child: _loading
                                  ? const Center(
                                  child: CircularProgressIndicator(
                                      color: Color(0xFF0F2D52)))
                                  : ElevatedButton(
                                onPressed: _signUp,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF0F2D52),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 15),
                                  shape: const StadiumBorder(),
                                ),
                                child: const Text('註冊',
                                    style: TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 1,
                                        fontFamily: 'Georgia')),
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextButton(
                              onPressed: () => Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) => const LoginPage())),
                              child: RichText(
                                text: const TextSpan(
                                  text: '已有帳號？',
                                  style: TextStyle(
                                      color: Color(0xFF2A5080),
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13),
                                  children: [
                                    TextSpan(
                                      text: '立即登入',
                                      style: TextStyle(color: Color(0xFF1A5FA8)),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 32),
                          ],
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
}