import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme/app_theme.dart';
import '../services/scan_store.dart';
import '../services/routine_store.dart';
import '../services/daily_tip_service.dart';

class HomeScreen extends StatefulWidget {
  final VoidCallback onFaceScanTap;
  final VoidCallback onSkinChatTap;
  final VoidCallback onRoutineTap;
  final VoidCallback onFindDermTap;

  const HomeScreen({super.key, required this.onFaceScanTap, required this.onSkinChatTap, required this.onRoutineTap, required this.onFindDermTap});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _name = 'there';

  @override
  void initState() {
    super.initState();
    _loadName();
    DailyTipService.instance.load();
  }

  Future<void> _loadName() async {
    final displayName = FirebaseAuth.instance.currentUser?.displayName;
    if (!mounted) return;
    if (displayName != null && displayName.isNotEmpty) setState(() => _name = displayName);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListenableBuilder(
           listenable: Listenable.merge([ScanStore.instance.results, RoutineStore.instance.done, RoutineStore.instance.label]),        builder: (context, _) {
          final history = ScanStore.instance.results.value;
          final morning = RoutineStore.instance.morning;
          final night = RoutineStore.instance.night;
          final mDone = morning.where((s) => RoutineStore.instance.isDone('morning', s.name)).length;
          final nDone = night.where((s) => RoutineStore.instance.isDone('night', s.name)).length;

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            children: [
              _greeting(),
              const SizedBox(height: 18),
              _overviewCard(history),
              const SizedBox(height: 14),
              _quickActionsGrid(),
              const SizedBox(height: 14),
              _glowUpChart(history),
              const SizedBox(height: 14),
              _progressCard(mDone + nDone, morning.length + night.length),
              const SizedBox(height: 14),
              _tipCard(),
              const SizedBox(height: 12),
              _disclaimer(),
            ],
          );
        },
      ),
    );
  }

  Widget _greeting() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Good morning 🌿', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.rose)),
            Text('Hello, $_name', style: GoogleFonts.fraunces(fontSize: 28, fontWeight: FontWeight.w600, color: AppColors.textDark, letterSpacing: -0.8)),
          ],
        ),
        Container(
          width: 48, height: 48,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [const Color(0xFFF5C6CF), AppColors.coral], begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(16),
          ),
          alignment: Alignment.center,
          child: const Text('🍓', style: TextStyle(fontSize: 22)),
        ),
      ],
    );
  }

  Widget _overviewCard(List<ScanResult> history) {
    final hasScan = history.isNotEmpty;
    final score = hasScan ? history.last.healthScore : 0;
    String? trendText;
    if (history.length >= 2) {
      final diff = history.last.healthScore - history[history.length - 2].healthScore;
      trendText = '${diff >= 0 ? '+' : ''}$diff% this week';
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: LinearGradient(colors: [const Color(0xFFF5A8BA), AppColors.coral], begin: Alignment.topLeft, end: Alignment.bottomRight),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -10, right: -6,
            child: Opacity(
              opacity: 0.35,
              child: Transform.rotate(angle: 0.25, child: const Text('🍓', style: TextStyle(fontSize: 46))),
            ),
          ),
          Positioned(
            top: 36, right: 34,
            child: Opacity(
              opacity: 0.3,
              child: Transform.rotate(angle: -0.2, child: const Text('🌿', style: TextStyle(fontSize: 26))),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Skin Health Overview', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 100, height: 100,
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CircularProgressIndicator(
                          value: hasScan ? score / 100 : 0,
                          strokeWidth: 9,
                          backgroundColor: const Color(0xFFF5E8D8),
                          valueColor: AlwaysStoppedAnimation(AppColors.coral),
                          strokeCap: StrokeCap.round,
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(hasScan ? '$score' : '--', style: GoogleFonts.fraunces(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                            Text('/ 100', style: TextStyle(fontSize: 10, color: AppColors.rose, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          hasScan ? 'Your skin looks healthier this week ✨' : 'Run a scan to see your skin health score ✨',
                          style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700, height: 1.35),
                        ),
                        if (trendText != null) ...[
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(color: Colors.white.withOpacity(0.25), borderRadius: BorderRadius.circular(999)),
                            child: Text('↑ $trendText', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _quickActionsGrid() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _gridButton('✨', 'Face Scan', [const Color(0xFF7FB069), AppColors.green], Colors.white, widget.onFaceScanTap)),
            const SizedBox(width: 10),
            Expanded(child: _gridButton('💬', 'Skin Chat', [AppColors.coral, AppColors.coralDeep], Colors.white, widget.onSkinChatTap)),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _gridButton('🍎', 'Nutrition', const [Color(0xFFDCEBC8), Color(0xFFC5E0B0)], const Color(0xFF3A5A28), widget.onRoutineTap)),
            const SizedBox(width: 10),
            Expanded(child: _gridButton('📍', 'Find a Derm', const [Color(0xFFFAD7DC), Color(0xFFF5C6CF)], const Color(0xFF9A4A5A), widget.onFindDermTap)),          ],
        ),
      ],
    );
  }

  Widget _gridButton(String emoji, String label, List<Color> colors, Color textColor, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.3), shape: BoxShape.circle),
              alignment: Alignment.center,
              child: Text(emoji, style: const TextStyle(fontSize: 18)),
            ),
            const SizedBox(height: 8),
            Text(label, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: textColor)),
          ],
        ),
      ),
    );
  }

  Widget _glowUpChart(List<ScanResult> history) {
    if (history.length < 2) {
      return _Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Your Skin Glow-Up', style: GoogleFonts.fraunces(fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.textDark)),
            const SizedBox(height: 10),
            Text('Scan a few times to start seeing your trend here.', style: TextStyle(fontSize: 12, color: AppColors.rose, fontWeight: FontWeight.w500)),
          ],
        ),
      );
    }
    final scores = history.map((r) => r.healthScore).toList();
    final change = scores.last - scores.first;
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Your Skin Glow-Up', style: GoogleFonts.fraunces(fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.textDark)),
              Text('${change >= 0 ? '+' : ''}$change points 🌱', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF4A8030))),
            ],
          ),
          Text('${scores.length}-scan timeline', style: TextStyle(fontSize: 11, color: AppColors.rose, fontWeight: FontWeight.w500)),
          const SizedBox(height: 14),
          SizedBox(
            height: 90,
            width: double.infinity,
            child: CustomPaint(painter: _LineChartPainter(scores), size: Size.infinite),
          ),
        ],
      ),
    );
  }

  Widget _progressCard(int done, int total) {
    final pct = total == 0 ? 0 : (done / total * 100).round();
    return Column(
      children: [
        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Today's progress", style: TextStyle(fontSize: 13, color: AppColors.rose, fontWeight: FontWeight.w600)),
                      Text('$done/$total steps', style: GoogleFonts.fraunces(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: AppColors.green.withOpacity(0.2), borderRadius: BorderRadius.circular(999)),
                    child: Text('$pct% done', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF4A8030))),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: total == 0 ? 0 : done / total,
                  minHeight: 10,
                  backgroundColor: const Color(0xFFF0E4D0),
                  color: AppColors.coral,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        _updateBanner(),
      ],
    );
  }

  Widget _updateBanner() {
    final history = ScanStore.instance.results.value;
    String text;
    if (history.isEmpty) {
      text = 'Take your first scan to get a personalised routine 🌱';
    } else if (history.length == 1) {
      text = 'Your personalised routine is ready 🌱';
    } else {
      final dryNow = history.last.scores['Dryness / dehydration'] ?? 0;
      final dryPrev = history[history.length - 2].scores['Dryness / dehydration'] ?? 0;
      final hydNow = (100 * (1 - dryNow)).round();
      final hydPrev = (100 * (1 - dryPrev)).round();
      final diff = hydNow - hydPrev;
      text = diff >= 0
          ? 'Your hydration improved by $diff%. Your routine has been updated 🌱'
          : 'Your hydration changed by $diff%. Your routine has been updated 🌱';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(color: AppColors.green.withOpacity(0.15), borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(color: AppColors.green.withOpacity(0.3), shape: BoxShape.circle),
            alignment: Alignment.center,
            child: const Icon(Icons.trending_up, size: 16, color: Color(0xFF2E6018)),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 12, color: Color(0xFF2E6018), fontWeight: FontWeight.w600, height: 1.4))),
        ],
      ),
    );
  }

  Widget _tipCard() {
    return ValueListenableBuilder<String?>(
      valueListenable: DailyTipService.instance.tip,
      builder: (context, tipText, _) {
        final display = tipText ?? "Omega-3 rich foods like avocado & salmon boost your skin's natural glow.";
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFFE8D7B8), Color(0xFFF0E8C8)]), borderRadius: BorderRadius.circular(20)),
          child: Row(children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.5), borderRadius: BorderRadius.circular(14)),
              alignment: Alignment.center,
              child: const Text('💡', style: TextStyle(fontSize: 22)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Tip of the Day', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: Color(0xFF5A4030))),
                  const SizedBox(height: 3),
                  Text(display, style: const TextStyle(fontSize: 12, color: Color(0xFF7A6050), fontWeight: FontWeight.w500, height: 1.45)),
                ],
              ),
            ),
          ]),
        );
      },
    );
  }

  Widget _disclaimer() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF5C6CF).withOpacity(0.15),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF5C6CF).withOpacity(0.35)),
      ),
      child: Text(
        '⚕️ AiSkin recommendations are educational only. Consult a dermatologist for medical concerns.',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 10, color: AppColors.rose, fontWeight: FontWeight.w500, height: 1.5),
      ),
    );
  }
}

class _LineChartPainter extends CustomPainter {
  final List<int> values;
  _LineChartPainter(this.values);

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    final maxV = values.reduce((a, b) => a > b ? a : b).toDouble();
    final minV = values.reduce((a, b) => a < b ? a : b).toDouble();
    final range = (maxV - minV) < 1 ? 1.0 : (maxV - minV);
    final stepX = size.width / (values.length - 1);

    Offset pointAt(int i) {
      final t = (values[i] - minV) / range;
      final y = size.height - (t * size.height * 0.8) - (size.height * 0.1);
      return Offset(stepX * i, y);
    }

    final path = Path();
    final fillPath = Path();
    for (int i = 0; i < values.length; i++) {
      final p = pointAt(i);
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
        fillPath.moveTo(p.dx, size.height);
        fillPath.lineTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
        fillPath.lineTo(p.dx, p.dy);
      }
    }
    fillPath.lineTo(stepX * (values.length - 1), size.height);
    fillPath.close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [AppColors.coral.withOpacity(0.35), AppColors.coral.withOpacity(0.0)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawPath(fillPath, fillPaint);

    final linePaint = Paint()
      ..color = AppColors.coral
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, linePaint);

    final dotPaint = Paint()..color = AppColors.coral;
    for (int i = 0; i < values.length; i++) {
      canvas.drawCircle(pointAt(i), 4, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter oldDelegate) => oldDelegate.values != values;
}

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20)),
      child: child,
    );
  }
}