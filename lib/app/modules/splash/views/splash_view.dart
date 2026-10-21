import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mangaplus/app/core/constants/colors.dart';
import 'package:mangaplus/app/routes/app_pages.dart';

class SplashView extends StatefulWidget {
  const SplashView({super.key});

  @override
  State<SplashView> createState() => _SplashViewState();
}

class _SplashViewState extends State<SplashView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _logoOpacity;
  late final Animation<double> _logoScale;
  late final Animation<double> _logoLift;
  late final Animation<double> _halo;
  late final Animation<double> _wordOne;
  late final Animation<double> _wordTwo;
  late final Animation<double> _wordThree;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2700),
    );

    _logoOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.25, curve: Curves.easeOut),
    );
    _logoScale = Tween<double>(begin: 0.72, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.42, curve: Curves.easeOutBack),
      ),
    );
    _logoLift = Tween<double>(begin: 12, end: 0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.42, curve: Curves.easeOutCubic),
      ),
    );
    _halo = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.08, 0.55, curve: Curves.easeOut),
    );
    _wordOne = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.43, 0.63, curve: Curves.easeOutCubic),
    );
    _wordTwo = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.55, 0.75, curve: Curves.easeOutCubic),
    );
    _wordThree = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.67, 0.87, curve: Curves.easeOutCubic),
    );

    _controller.forward();
    Timer(const Duration(milliseconds: 2850), () {
      if (mounted) Get.offAllNamed(Routes.MAIN);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final foreground = theme.colorScheme.onSurface;
    final muted = foreground.withValues(alpha: isDark ? 0.68 : 0.56);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Transform.translate(
                offset: Offset(0, _logoLift.value),
                child: Transform.scale(
                  scale: _logoScale.value,
                  child: Opacity(
                    opacity: _logoOpacity.value,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 214,
                          height: 188,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withValues(
                                  alpha: 0.04 + (_halo.value * 0.13),
                                ),
                                blurRadius: 58,
                                spreadRadius: 12 + (_halo.value * 10),
                              ),
                            ],
                          ),
                        ),
                        Image.asset(
                          'assets/images/mangaplus_logo.png',
                          width: 154,
                          height: 130,
                          fit: BoxFit.contain,
                          filterQuality: FilterQuality.high,
                          gaplessPlayback: true,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _AnimatedWord(
                    word: 'إقراء',
                    animation: _wordOne,
                    color: foreground,
                  ),
                  _AnimatedSeparator(
                    animation: _wordTwo,
                    color: muted,
                  ),
                  _AnimatedWord(
                    word: 'استمتع',
                    animation: _wordTwo,
                    color: foreground,
                  ),
                  _AnimatedSeparator(
                    animation: _wordThree,
                    color: muted,
                  ),
                  _AnimatedWord(
                    word: 'زامن',
                    animation: _wordThree,
                    color: foreground,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Opacity(
                opacity: _wordThree.value,
                child: Container(
                  width: 42 + (_wordThree.value * 26),
                  height: 2,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.72),
                    borderRadius: BorderRadius.circular(2),
                    boxShadow: [
                      BoxShadow(
                        color: theme.colorScheme.primary.withValues(alpha: 0.26),
                        blurRadius: 9,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AnimatedWord extends StatelessWidget {
  const _AnimatedWord({
    required this.word,
    required this.animation,
    required this.color,
  });

  final String word;
  final Animation<double> animation;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.32),
          end: Offset.zero,
        ).animate(animation),
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.82, end: 1).animate(animation),
          child: Text(
            word,
            style: theme.textTheme.titleMedium?.copyWith(
              color: color,
              fontSize: 17,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.15,
              height: 1.1,
            ),
          ),
        ),
      ),
    );
  }
}

class _AnimatedSeparator extends StatelessWidget {
  const _AnimatedSeparator({required this.animation, required this.color});

  final Animation<double> animation;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: animation,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9),
        child: Text(
          '·',
          style: TextStyle(
            color: color,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
