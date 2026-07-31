import 'dart:math';
import 'package:flutter/material.dart';

class _FloatingParticle {
  final double x;
  final double y;
  final double size;
  final double opacity;
  final int speed;
  final double rotationOffset;
  final String emoji;

  const _FloatingParticle({
    required this.x,
    required this.y,
    required this.size,
    required this.opacity,
    required this.speed,
    required this.rotationOffset,
    required this.emoji,
  });
}

class FloatingParticlesBackground extends StatefulWidget {
  final bool isDark;
  final Widget child;

  const FloatingParticlesBackground({
    super.key,
    required this.isDark,
    required this.child,
  });

  @override
  State<FloatingParticlesBackground> createState() =>
      _FloatingParticlesBackgroundState();
}

class _FloatingParticlesBackgroundState
    extends State<FloatingParticlesBackground>
    with TickerProviderStateMixin {
  late List<AnimationController> _controllers;
  late List<_FloatingParticle> _particles;

  static const List<String> _foodEmojis = [
    '🌶️',
    '🧀',
    '🍅',
    '🧅',
    '🌿',
    '🫑',
    '🍋',
    '🫐',
    '🌽',
    '🍄',
    '🫚',
    '🥦',
  ];

  final _rng = Random(42);

  @override
  void initState() {
    super.initState();
    _particles = List.generate(12, (i) {
      return _FloatingParticle(
        x: _rng.nextDouble(),
        y: _rng.nextDouble(),
        size: 14 + _rng.nextDouble() * 14,
        opacity: 0.05 + _rng.nextDouble() * 0.08,
        speed: 2000 + _rng.nextInt(3000),
        rotationOffset: _rng.nextDouble() * 6.28,
        emoji: _foodEmojis[i % _foodEmojis.length],
      );
    });

    _controllers = _particles.map((p) {
      return AnimationController(
        vsync: this,
        duration: Duration(milliseconds: p.speed),
      )..repeat(reverse: true);
    }).toList();
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;

    return Stack(
      children: [
        // Gradient background
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: isDark
                  ? const LinearGradient(
                      colors: [
                        Color(0xFF0F0F0F),
                        Color(0xFF1A0808),
                        Color(0xFF0F0F0F),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    )
                  : const LinearGradient(
                      colors: [
                        Color(0xFFFFF8F5),
                        Color(0xFFFFF0EF),
                        Color(0xFFFAFAFA),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
            ),
          ),
        ),

        // Soft radial accent glow
        Positioned(
          top: -60,
          left: -60,
          child: Container(
            width: 240,
            height: 240,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  const Color(0xFFFF4D4F).withOpacity(isDark ? 0.06 : 0.04),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),

        // Floating particle emojis
        ...List.generate(_particles.length, (i) {
          final p = _particles[i];
          return AnimatedBuilder(
            animation: _controllers[i],
            builder: (context, _) {
              final t = _controllers[i].value;
              final yOffset = sin(t * pi) * 18;
              final xOffset = cos(t * pi + p.rotationOffset) * 8;
              return Positioned(
                left: p.x * MediaQuery.of(context).size.width + xOffset,
                top: p.y * 600 + yOffset,
                child: Opacity(
                  opacity: p.opacity,
                  child: Text(
                    p.emoji,
                    style: TextStyle(fontSize: p.size),
                  ),
                ),
              );
            },
          );
        }),

        // Main content on top
        widget.child,
      ],
    );
  }
}
