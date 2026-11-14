import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mangaplus/app/core/theme/app_motion.dart';
import 'package:mangaplus/app/core/theme/app_palette.dart';
import 'package:mangaplus/app/core/theme/design_tokens.dart';
import 'package:mangaplus/app/widgets/app_surfaces.dart';

/// Adds press feedback to any tappable surface without taking over its gestures.
///
/// A [Listener] is used on purpose: it observes pointer events without entering
/// the gesture arena, so an inner `InkWell`, button or `GestureDetector` keeps
/// receiving its taps exactly as before. The scale collapses to 1 when the
/// platform requests reduced motion.
class PressableScale extends StatefulWidget {
  const PressableScale({
    super.key,
    required this.child,
    this.enabled = true,
    this.scale = AppMotion.pressedScale,
  });

  final Widget child;
  final bool enabled;
  final double scale;

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final target = _pressed && widget.enabled
        ? (AppMotion.reduceMotion(context) ? 1.0 : widget.scale)
        : 1.0;
    return Listener(
      // Translucent so the feedback also works over painters and empty
      // containers, without consuming events from the wrapped control.
      behavior: HitTestBehavior.translucent,
      onPointerDown: widget.enabled ? (_) => _setPressed(true) : null,
      onPointerUp: (_) => _setPressed(false),
      onPointerCancel: (_) => _setPressed(false),
      child: AnimatedScale(
        scale: target,
        duration: AppMotion.effective(context, AppMotion.instant),
        curve: AppMotion.enter,
        child: widget.child,
      ),
    );
  }
}

/// Fades and lifts a widget in once, when it first becomes visible.
///
/// Used for state widgets, detail headers and section entrances — never for
/// rows inside a scrolling list, where per-item animation would compete with
/// scrolling. Animation state lives in the widget, so it survives rebuilds and
/// is disposed with it.
class AnimatedEntry extends StatefulWidget {
  const AnimatedEntry({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = AppMotion.entrance,
    this.slideOffset = AppMotion.entranceOffset,
  });

  final Widget child;
  final Duration delay;
  final Duration duration;
  final double slideOffset;

  @override
  State<AnimatedEntry> createState() => _AnimatedEntryState();
}

class _AnimatedEntryState extends State<AnimatedEntry>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  );
  late final Animation<double> _fade = CurvedAnimation(
    parent: _controller,
    curve: AppMotion.enter,
  );
  late final Animation<Offset> _slide = Tween<Offset>(
    begin: Offset(0, widget.slideOffset),
    end: Offset.zero,
  ).animate(_fade);

  Timer? _delayTimer;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (AppMotion.reduceMotion(context)) {
      _controller.value = 1;
      return;
    }
    if (widget.delay == Duration.zero) {
      _controller.forward();
    } else {
      _delayTimer = Timer(widget.delay, () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _delayTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}

/// Cross-fades between two states of the same region (loading → content,
/// saved → removed) with a light scale so the change reads as a transition
/// rather than a jump.
class AnimatedContentSwitcher extends StatelessWidget {
  const AnimatedContentSwitcher({
    super.key,
    required this.child,
    this.duration,
    this.alignment = Alignment.center,
  });

  final Widget child;
  final Duration? duration;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: AppMotion.effective(context, duration ?? AppMotion.normal),
      switchInCurve: AppMotion.curve(context, AppMotion.enter),
      switchOutCurve: AppMotion.curve(context, AppMotion.exit),
      layoutBuilder: (current, previous) => Stack(
        alignment: alignment,
        children: [
          ...previous,
          if (current != null) current,
        ],
      ),
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          scale: Tween<double>(begin: .985, end: 1).animate(animation),
          child: child,
        ),
      ),
      child: child,
    );
  }
}

/// A settings-style row that reveals its content with an animated height.
///
/// Collapsed content is not built at all, so a closed section costs nothing;
/// the height transition uses [AnimatedSize] which animates layout once, not
/// per frame.
class AppExpandable extends StatefulWidget {
  const AppExpandable({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.trailing,
    required this.child,
    this.initiallyExpanded = false,
    this.expandedLabel,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final Widget? trailing;
  final Widget child;
  final bool initiallyExpanded;

  /// Optional semantics label announced when the section opens.
  final String? expandedLabel;

  @override
  State<AppExpandable> createState() => _AppExpandableState();
}

class _AppExpandableState extends State<AppExpandable> {
  late bool _expanded = widget.initiallyExpanded;

  void _toggle() => setState(() => _expanded = !_expanded);

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    final duration = AppMotion.effective(context, AppMotion.normal);
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            button: true,
            expanded: _expanded,
            label: _expanded ? widget.expandedLabel : widget.title,
            child: InkWell(
              onTap: _toggle,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                child: Row(
                  children: [
                    if (widget.icon != null) ...[
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: p.primary.withValues(alpha: .12),
                          borderRadius: AppRadii.smAll,
                        ),
                        alignment: Alignment.center,
                        child: Icon(widget.icon, size: 19, color: p.icon),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(widget.title, style: text.titleSmall),
                          if (widget.subtitle != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                widget.subtitle!,
                                style: text.bodySmall,
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (widget.trailing != null) widget.trailing!,
                    AnimatedRotation(
                      turns: _expanded ? .5 : 0,
                      duration: duration,
                      curve: AppMotion.standard,
                      child: Icon(
                        Icons.expand_more_rounded,
                        size: AppSizes.icon,
                        color: p.icon,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          AnimatedSize(
            duration: duration,
            curve: AppMotion.standard,
            alignment: Alignment.topCenter,
            child: _expanded
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md,
                      0,
                      AppSpacing.md,
                      AppSpacing.md,
                    ),
                    child: widget.child,
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}
