import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:gap/gap.dart';

class PremiumScreen extends StatefulWidget {
  const PremiumScreen({super.key});

  @override
  State<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends State<PremiumScreen>
    with TickerProviderStateMixin {
  int _selectedPlan = 1; // 0 = Monthly, 1 = Yearly (default)
  late AnimationController _shimmerController;
  late AnimationController _orbitController;

  static const _plans = [
    {
      'label': 'Monthly',
      'price': '₹149',
      'per': '/month',
      'badge': '',
      'saving': '',
    },
    {
      'label': 'Yearly',
      'price': '₹999',
      'per': '/year',
      'badge': 'BEST VALUE',
      'saving': 'Save ₹789',
    },
  ];

  static const _benefits = [
    {
      'icon': Iconsax.truck,
      'title': 'Free Delivery',
      'desc': 'Zero delivery charges on every order, always.',
      'color': Color(0xFF22C55E),
    },
    {
      'icon': Iconsax.ticket_discount,
      'title': 'Exclusive Discounts',
      'desc': 'Up to 40% off on 500+ premium restaurants.',
      'color': Color(0xFF3B82F6),
    },
    {
      'icon': Iconsax.flash,
      'title': 'Faster Delivery',
      'desc': 'Priority delivery — get food in 20 mins or less.',
      'color': Color(0xFFF59E0B),
    },
    {
      'icon': Iconsax.crown,
      'title': 'VIP Offers',
      'desc': 'Early access to flash sales, new restaurants & events.',
      'color': Color(0xFFEC4899),
    },
    {
      'icon': Iconsax.gift,
      'title': 'Free Items Monthly',
      'desc': 'Complimentary desserts, drinks & more every month.',
      'color': Color(0xFF8B5CF6),
    },
    {
      'icon': Iconsax.headphone,
      'title': 'Priority Support',
      'desc': '24/7 dedicated premium customer service line.',
      'color': Color(0xFF06B6D4),
    },
  ];

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    _orbitController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    _orbitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFF0D0800),
      body: Stack(
        children: [
          // ── Premium gold radial background ──
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0, -0.6),
                  radius: 1.4,
                  colors: [
                    Color(0xFF3A2000),
                    Color(0xFF1A0E00),
                    Color(0xFF0D0800),
                  ],
                ),
              ),
            ),
          ),

          // ── Orbiting glow rings ──
          AnimatedBuilder(
            animation: _orbitController,
            builder: (_, __) {
              return CustomPaint(
                size: Size(size.width, size.height * 0.45),
                painter: _OrbitPainter(_orbitController.value),
              );
            },
          ),

          // ── Main scrollable content ──
          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Gap(16),

                    // ── Back button ──
                    Align(
                      alignment: Alignment.centerLeft,
                      child: GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.08),
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: Colors.white.withOpacity(0.12)),
                          ),
                          child: const Icon(Icons.arrow_back_ios_new_rounded,
                              color: Colors.white70, size: 16),
                        ),
                      ),
                    ),

                    const Gap(24),

                    // ── Crown icon with glow ──
                    _GlowingCrown(shimmer: _shimmerController)
                        .animate()
                        .scale(
                            begin: const Offset(0.5, 0.5),
                            duration: 700.ms,
                            curve: Curves.elasticOut)
                        .fadeIn(duration: 500.ms),

                    const Gap(20),

                    // ── Title ──
                    AnimatedBuilder(
                      animation: _shimmerController,
                      builder: (_, __) {
                        return ShaderMask(
                          shaderCallback: (bounds) {
                            final t = _shimmerController.value;
                            return LinearGradient(
                              colors: const [
                                Color(0xFFB8860B),
                                Color(0xFFFFD700),
                                Color(0xFFFFF8DC),
                                Color(0xFFFFD700),
                                Color(0xFFB8860B),
                              ],
                              stops: [
                                (t - 0.4).clamp(0.0, 1.0),
                                (t - 0.2).clamp(0.0, 1.0),
                                t.clamp(0.0, 1.0),
                                (t + 0.2).clamp(0.0, 1.0),
                                (t + 0.4).clamp(0.0, 1.0),
                              ],
                            ).createShader(bounds);
                          },
                          child: Text(
                            'Gold Membership',
                            style: GoogleFonts.poppins(
                              fontSize: 30,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: -0.5,
                            ),
                          ),
                        );
                      },
                    ).animate().fadeIn(duration: 600.ms, delay: 200.ms),

                    const Gap(8),

                    Text(
                      'Unlock a world of exclusive food privileges',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: Colors.amber.withOpacity(0.6),
                        fontWeight: FontWeight.w400,
                      ),
                    )
                        .animate()
                        .fadeIn(duration: 500.ms, delay: 300.ms),

                    const Gap(32),

                    // ── Plan selector ──
                    _PlanSelector(
                      selectedPlan: _selectedPlan,
                      plans: _plans,
                      onPlanSelected: (i) => setState(() => _selectedPlan = i),
                    )
                        .animate()
                        .fadeIn(duration: 500.ms, delay: 400.ms)
                        .slideY(
                            begin: 0.2, end: 0, duration: 500.ms, delay: 400.ms),

                    const Gap(32),

                    // ── Benefits section ──
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'What you get 🎁',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),

                    const Gap(14),

                    // Benefits grid
                    ...List.generate(_benefits.length, (i) {
                      final b = _benefits[i];
                      return _BenefitTile(
                        icon: b['icon'] as IconData,
                        title: b['title'] as String,
                        desc: b['desc'] as String,
                        color: b['color'] as Color,
                        index: i,
                      );
                    }),

                    const Gap(32),

                    // ── Buy Premium CTA ──
                    _BuyPremiumButton(
                      plan: _plans[_selectedPlan],
                      shimmer: _shimmerController,
                    )
                        .animate()
                        .fadeIn(duration: 600.ms, delay: 600.ms)
                        .slideY(
                            begin: 0.3, end: 0, duration: 600.ms, delay: 600.ms),

                    const Gap(12),

                    Text(
                      'Cancel anytime · Secure payment · Auto-renews',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: Colors.white.withOpacity(0.3),
                      ),
                    ),

                    const Gap(40),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Orbiting glow painter ──────────────────────────────────────────────────
class _OrbitPainter extends CustomPainter {
  final double t;
  _OrbitPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height * 0.35;

    void drawRing(double radius, double opacity, double phase) {
      final angle = 2 * math.pi * (t + phase);
      final paint = Paint()
        ..color = const Color(0xFFFFD700).withOpacity(opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2;
      canvas.drawCircle(Offset(cx, cy), radius, paint);

      // Glowing dot on ring
      final dx = cx + math.cos(angle) * radius;
      final dy = cy + math.sin(angle) * radius;
      final dotPaint = Paint()
        ..color = const Color(0xFFFFD700).withOpacity(opacity * 2.5)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
      canvas.drawCircle(Offset(dx, dy), 4, dotPaint);
    }

    drawRing(80, 0.10, 0.0);
    drawRing(130, 0.07, 0.33);
    drawRing(175, 0.05, 0.67);
  }

  @override
  bool shouldRepaint(_OrbitPainter old) => old.t != t;
}

// ── Crown widget ────────────────────────────────────────────────────────────
class _GlowingCrown extends StatelessWidget {
  final AnimationController shimmer;
  const _GlowingCrown({required this.shimmer});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 96,
      height: 96,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const RadialGradient(
          colors: [Color(0xFF4A3000), Color(0xFF1A0E00)],
        ),
        border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.4), width: 2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFFD700).withOpacity(0.35),
            blurRadius: 30,
            spreadRadius: 4,
          ),
        ],
      ),
      child: const Icon(Iconsax.crown5, size: 46, color: Color(0xFFFFD700)),
    );
  }
}

// ── Plan Selector ──────────────────────────────────────────────────────────
class _PlanSelector extends StatelessWidget {
  final int selectedPlan;
  final List<Map<String, String>> plans;
  final ValueChanged<int> onPlanSelected;

  const _PlanSelector({
    required this.selectedPlan,
    required this.plans,
    required this.onPlanSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(plans.length, (i) {
        final plan = plans[i];
        final isSelected = selectedPlan == i;
        return Expanded(
          child: GestureDetector(
            onTap: () => onPlanSelected(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              margin: EdgeInsets.only(right: i == 0 ? 10 : 0),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: isSelected
                    ? const LinearGradient(
                        colors: [Color(0xFFFFD700), Color(0xFFFF8C00)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                color: isSelected ? null : Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected
                      ? Colors.transparent
                      : Colors.white.withOpacity(0.15),
                  width: 1.5,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: const Color(0xFFFFD700).withOpacity(0.4),
                          blurRadius: 20,
                          offset: const Offset(0, 6),
                        )
                      ]
                    : null,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (plan['badge']!.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Colors.white.withOpacity(0.25)
                            : const Color(0xFFFFD700).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        plan['badge']!,
                        style: GoogleFonts.poppins(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: isSelected
                              ? Colors.white
                              : const Color(0xFFFFD700),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  Text(
                    plan['label']!,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? Colors.white
                          : Colors.white.withOpacity(0.6),
                    ),
                  ),
                  const Gap(4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        plan['price']!,
                        style: GoogleFonts.poppins(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          color: isSelected ? Colors.white : Colors.white70,
                          height: 1,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 3),
                        child: Text(
                          plan['per']!,
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: isSelected
                                ? Colors.white70
                                : Colors.white38,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (plan['saving']!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        plan['saving']!,
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: isSelected
                              ? Colors.white.withOpacity(0.9)
                              : const Color(0xFF22C55E),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }
}

// ── Benefit Tile ────────────────────────────────────────────────────────────
class _BenefitTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String desc;
  final Color color;
  final int index;

  const _BenefitTile({
    required this.icon,
    required this.title,
    required this.desc,
    required this.color,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const Gap(14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const Gap(2),
                Text(
                  desc,
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: Colors.white.withOpacity(0.45),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.check_circle_rounded, color: color, size: 18),
        ],
      ),
    )
        .animate(delay: Duration(milliseconds: 500 + index * 80))
        .fadeIn(duration: 400.ms)
        .slideX(begin: 0.2, end: 0, duration: 400.ms, curve: Curves.easeOut);
  }
}

// ── Buy Premium Button ─────────────────────────────────────────────────────
class _BuyPremiumButton extends StatelessWidget {
  final Map<String, String> plan;
  final AnimationController shimmer;

  const _BuyPremiumButton({required this.plan, required this.shimmer});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '🎉 Welcome to Gold! ${plan['label']} plan activated.',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
            backgroundColor: const Color(0xFFFFD700),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
          ),
        );
      },
      child: AnimatedBuilder(
        animation: shimmer,
        builder: (_, child) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                colors: const [
                  Color(0xFFB8860B),
                  Color(0xFFFFD700),
                  Color(0xFFFFF8DC),
                  Color(0xFFFFD700),
                  Color(0xFFB8860B),
                ],
                stops: [
                  (shimmer.value - 0.4).clamp(0.0, 1.0),
                  (shimmer.value - 0.2).clamp(0.0, 1.0),
                  shimmer.value.clamp(0.0, 1.0),
                  (shimmer.value + 0.2).clamp(0.0, 1.0),
                  (shimmer.value + 0.4).clamp(0.0, 1.0),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFFD700).withOpacity(0.45),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: child,
          );
        },
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Iconsax.crown5, color: Colors.black87, size: 20),
            const Gap(10),
            Text(
              'Buy Premium — ${plan['price']}${plan['per']}',
              style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                color: Colors.black87,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
