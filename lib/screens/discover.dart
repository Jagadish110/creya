import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app_state.dart';
import '../icons.dart';
import '../mock_data.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets.dart';

/// 04 · Discover
class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  static const _swipeDuration = Duration(milliseconds: 260);
  static const _swipeThreshold = 110.0;
  static const _openProfileThreshold = -120.0;

  double _dx = 0;
  double _dy = 0;
  bool _dragging = false;
  SwipeDirection? _leaving;
  bool _muted = true;

  void _swipe(AppState app, SwipeDirection direction) {
    final deck = app.visibleDeck;
    if (deck.isEmpty || _leaving != null) return;
    final id = deck.first;
    setState(() {
      _leaving = direction;
      _dragging = false;
    });
    Timer(_swipeDuration, () {
      app.finishSwipe(id, direction);
      if (!mounted) return;
      setState(() {
        _dx = 0;
        _dy = 0;
        _leaving = null;
        _muted = true;
      });
    });
  }

  void _onPanEnd(AppState app, Person top) {
    if (!_dragging) return;
    if (_dx > _swipeThreshold) return _swipe(app, SwipeDirection.right);
    if (_dx < -_swipeThreshold) return _swipe(app, SwipeDirection.left);
    final openProfile = _dy < _openProfileThreshold;
    setState(() {
      _dragging = false;
      _dx = 0;
      _dy = 0;
    });
    if (openProfile) app.openPerson(top.id);
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final deck = app.visibleDeck;
    final top = deck.isNotEmpty ? people[deck[0]] : null;
    final next = deck.length > 1 ? people[deck[1]] : null;

    return Column(
      children: [
        SizedBox(
          height: 52,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Wordmark(size: 30),
                Text(
                  '${deck.length} nearby',
                  style: const TextStyle(fontSize: 13, color: AppColors.muted),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    if (next != null)
                      Opacity(
                        key: ValueKey('next-${next.id}'),
                        opacity: 0.6,
                        child: Transform.translate(
                          offset: const Offset(0, 14),
                          child: Transform.scale(
                            scale: 0.94,
                            child: GradientBox(
                              gradient: next.bg,
                              borderRadius: BorderRadius.circular(28),
                            ),
                          ),
                        ),
                      ),
                    if (top != null)
                      _buildTopCard(app, top, constraints.maxWidth)
                    else
                      _CaughtUp(onRefresh: app.resetDeck),
                  ],
                );
              },
            ),
          ),
        ),
        SizedBox(
          height: 96,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            spacing: 22,
            children: [
              CircleIconButton(
                icon: AppIcons.close,
                label: 'Skip',
                onTap: () => _swipe(app, SwipeDirection.left),
                size: 60,
                iconSize: 26,
                strokeWidth: 2.5,
                foreground: AppColors.declined,
                border: const BorderSide(color: AppColors.line),
                pressedScale: 0.92,
              ),
              CircleIconButton(
                icon: AppIcons.user,
                label: 'View profile',
                onTap: top == null ? null : () => app.openPerson(top.id),
                size: 48,
                border: const BorderSide(color: AppColors.line),
                pressedScale: 0.92,
              ),
              CircleIconButton(
                icon: AppIcons.plus,
                label: 'Connect',
                onTap: () => _swipe(app, SwipeDirection.right),
                size: 60,
                iconSize: 26,
                strokeWidth: 2.5,
                background: AppColors.accent,
                foreground: AppColors.onAccent,
                pressedScale: 0.92,
                shadow: const BoxShadow(
                  color: Color(0x26FFFFFF),
                  blurRadius: 30,
                  offset: Offset(0, 10),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTopCard(AppState app, Person top, double width) {
    final offscreen = math.max(520.0, width * 1.4);
    final tx = switch (_leaving) {
      SwipeDirection.right => offscreen,
      SwipeDirection.left => -offscreen,
      null => _dx,
    };
    final transform = Matrix4.identity()
      ..translateByDouble(tx, _dy, 0, 1)
      ..rotateZ((tx / 20) * math.pi / 180);

    return AnimatedContainer(
      key: ValueKey('top-${top.id}'),
      duration: _dragging ? Duration.zero : _swipeDuration,
      curve: const Cubic(0.2, 0.8, 0.2, 1),
      transform: transform,
      transformAlignment: Alignment.center,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() => _muted = !_muted),
        onPanStart: (_) {
          if (_leaving == null) setState(() => _dragging = true);
        },
        onPanUpdate: (details) {
          if (!_dragging) return;
          setState(() {
            _dx += details.delta.dx;
            _dy = (_dy + details.delta.dy).clamp(-200, 40);
          });
        },
        onPanEnd: (_) => _onPanEnd(app, top),
        onPanCancel: () => _onPanEnd(app, top),
        child: _ProfileCard(
          person: top,
          muted: _muted,
          connectOpacity: (tx / 100).clamp(0, 1),
          skipOpacity: (-tx / 100).clamp(0, 1),
        ),
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.person,
    required this.muted,
    required this.connectOpacity,
    required this.skipOpacity,
  });

  final Person person;
  final bool muted;
  final double connectOpacity;
  final double skipOpacity;

  @override
  Widget build(BuildContext context) {
    return GradientBox(
      gradient: person.bg,
      borderRadius: BorderRadius.circular(28),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: Row(
              spacing: 4,
              children: [
                for (var i = 0; i < 3; i++)
                  Expanded(
                    child: Container(
                      height: 3,
                      decoration: BoxDecoration(
                        color: i == 0 ? Colors.white : const Color(0x59FFFFFF),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Positioned(
            top: 28,
            right: 14,
            child: Semantics(
              label: muted ? 'Sound off' : 'Sound on',
              child: Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: Color(0x66000000),
                  shape: BoxShape.circle,
                ),
                child: AppIcon(
                  muted ? AppIcons.volumeMuted : AppIcons.volumeOn,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            ),
          ),
          Positioned(
            top: 36,
            left: 20,
            child: Text(
              'Talent clip · 0:20'.toUpperCase(),
              style: const TextStyle(
                fontFamily: AppFonts.mono,
                fontSize: 11,
                letterSpacing: 0.88,
                color: Color(0xB3FFFFFF),
              ),
            ),
          ),
          Positioned(
            top: 70,
            left: 20,
            child: _Stamp(
              label: 'CONNECT',
              color: AppColors.accepted,
              degrees: -12,
              opacity: connectOpacity,
            ),
          ),
          Positioned(
            top: 70,
            right: 20,
            child: _Stamp(
              label: 'SKIP',
              color: AppColors.declined,
              degrees: 12,
              opacity: skipOpacity,
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _CardFooter(person: person),
          ),
        ],
      ),
    );
  }
}

class _Stamp extends StatelessWidget {
  const _Stamp({
    required this.label,
    required this.color,
    required this.degrees,
    required this.opacity,
  });

  final String label;
  final Color color;
  final double degrees;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: opacity,
      child: Transform.rotate(
        angle: degrees * math.pi / 180,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            border: Border.all(color: color, width: 2.5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 20,
              letterSpacing: 1.2,
            ),
          ),
        ),
      ),
    );
  }
}

class _CardFooter extends StatelessWidget {
  const _CardFooter({required this.person});

  final Person person;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 80, 20, 20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Color(0xEB08080C), Color(0xEB08080C), Color(0x0008080C)],
          stops: [0, 0.3, 1],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 8,
        children: [
          Text(
            person.name,
            style: const TextStyle(
              fontFamily: AppFonts.heading,
              fontWeight: FontWeight.w600,
              fontSize: 36,
              height: 1,
            ),
          ),
          DefaultTextStyle.merge(
            style: const TextStyle(fontSize: 14, color: Color(0xCCFFFFFF)),
            child: Row(
              spacing: 6,
              children: [
                Text(
                  person.creative,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const Text('·'),
                const AppIcon(
                  AppIcons.mapPin,
                  color: Color(0xCCFFFFFF),
                  size: 14,
                ),
                Flexible(child: Text(person.city, maxLines: 1)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final genre in person.genres)
                  Tag(
                    label: genre,
                    height: 28,
                    fontWeight: FontWeight.w500,
                    background: const Color(0x24FFFFFF),
                    foreground: Colors.white,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CaughtUp extends StatelessWidget {
  const _CaughtUp({required this.onRefresh});

  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        spacing: 12,
        children: [
          const Heading(
            "You're all ",
            em: 'caught up.',
            size: 34,
            height: 1.2,
            textAlign: TextAlign.center,
          ),
          const Text(
            'New creatives join every day. Post a collab so the right people find you.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.muted,
              fontSize: 15,
              height: 1.5,
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: PillButton.outline(
              label: 'Refresh queue',
              onTap: onRefresh,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}
