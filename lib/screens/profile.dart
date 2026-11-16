import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../app_state.dart';
import '../icons.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets.dart';

/// 10 · Profile: your own, someone else's, or a preview of yours.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final isPerson = app.sub == SubScreen.person;
    final isPreview = isPerson && app.previewing;
    final isOther = isPerson && !app.previewing;
    final isMe = !isPerson;
    final Person person = isOther ? app.viewed! : app.me;
    final top = MediaQuery.paddingOf(context).top;

    return ColoredBox(
      color: AppColors.bg,
      child: SingleChildScrollView(
        child: Stack(
          children: [
            SizedBox(
              height: 250,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Keyed by clip, so a replaced clip starts from scratch.
                  _ClipHeader(key: ValueKey(person.clip), person: person),
                  const Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    height: 90,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [AppColors.bg, Color(0x000A0A0A)],
                        ),
                      ),
                    ),
                  ),
                  if (isPerson)
                    Positioned(
                      top: top + 7,
                      left: 16,
                      child: CircleIconButton(
                        icon: AppIcons.chevronLeft,
                        onTap: app.closeSub,
                        label: 'Back',
                        background: const Color(0x73000000),
                        foreground: Colors.white,
                      ),
                    ),
                  if (isMe)
                    Positioned(
                      top: top + 7,
                      right: 16,
                      child: CircleIconButton(
                        icon: AppIcons.settings,
                        onTap: app.openSettings,
                        label: 'Settings',
                        strokeWidth: 2,
                        background: const Color(0x73000000),
                        foreground: Colors.white,
                      ),
                    ),
                  if (isPreview)
                    Positioned(
                      top: top + 11,
                      left: 72,
                      right: 16,
                      height: 36,
                      child: Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: const Color(0x8C000000),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text(
                          'Previewing as others see you',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 198, 20, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 16,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      width: 96,
                      height: 96,
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: AppColors.bg,
                        shape: BoxShape.circle,
                      ),
                      child: Avatar(
                        person: person,
                        size: 88,
                        fontSize: 36,
                        style: const TextStyle(
                          fontFamily: AppFonts.heading,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 6,
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
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: person.creative,
                              style: const TextStyle(
                                color: AppColors.text,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            TextSpan(text: ' · ${person.city}'),
                          ],
                        ),
                        style: const TextStyle(
                          fontSize: 15,
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final genre in person.genres)
                        Tag(
                          label: genre,
                          height: 30,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          background: AppColors.card2,
                          foreground: AppColors.text,
                        ),
                    ],
                  ),
                  Text(
                    person.bio,
                    style: const TextStyle(fontSize: 15, height: 1.55),
                  ),
                  const Row(
                    spacing: 10,
                    children: [
                      _SocialIcon(AppIcons.instagram, 'Instagram'),
                      _SocialIcon(AppIcons.youtube, 'YouTube'),
                      _SocialIcon(AppIcons.audioLines, 'Audio'),
                      _SocialIcon(AppIcons.globe, 'Website'),
                    ],
                  ),
                  Row(
                    spacing: 6,
                    children: [
                      _Thumb(CssGradient.fromHue(person.hue, 40)),
                      _Thumb(CssGradient.fromHue((person.hue + 30) % 360, 90)),
                      _Thumb(
                        CssGradient.fromHue((person.hue + 300) % 360, -30),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 16,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: '${person.connections}',
                                style: const TextStyle(
                                  fontFamily: AppFonts.heading,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 30,
                                  height: 1,
                                  color: AppColors.text,
                                ),
                              ),
                              const TextSpan(text: '  connections'),
                            ],
                          ),
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 14,
                          ),
                        ),
                        const AppIcon(
                          AppIcons.chevronRight,
                          color: AppColors.muted,
                          size: 18,
                        ),
                      ],
                    ),
                  ),
                  if (isMe)
                    Row(
                      spacing: 8,
                      children: [
                        Expanded(
                          child: PillButton(
                            label: 'Edit profile',
                            onTap: app.editProfile,
                            height: 50,
                            fontSize: 15,
                          ),
                        ),
                        Expanded(
                          child: PillButton.outline(
                            label: 'Preview as others',
                            onTap: app.previewMyProfile,
                            height: 50,
                            fontSize: 15,
                            padding: EdgeInsets.zero,
                          ),
                        ),
                      ],
                    ),
                  if (isOther) ...[
                    PillButton(
                      label: 'Send connection request',
                      onTap: app.connectWithViewed,
                      height: 52,
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      spacing: 24,
                      children: [
                        _TextAction(
                          label: 'Report',
                          color: AppColors.muted,
                          onTap: () => app.showToast(
                            'Report sent. Our team reviews every one.',
                          ),
                        ),
                        _TextAction(
                          label: 'Block',
                          color: AppColors.declined,
                          onTap: app.blockViewed,
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The profile's header artwork. Tapping it plays the person's talent clip
/// in place, and tapping again pauses it. The player is only created on the
/// first tap, so opening a profile costs nothing.
class _ClipHeader extends StatefulWidget {
  const _ClipHeader({super.key, required this.person});

  final Person person;

  @override
  State<_ClipHeader> createState() => _ClipHeaderState();
}

class _ClipHeaderState extends State<_ClipHeader> {
  VideoPlayerController? _controller;
  bool _loading = false;
  bool _failed = false;

  Future<void> _toggle() async {
    final clip = widget.person.clip;
    if (clip == null || _loading) return;

    final existing = _controller;
    if (existing != null) {
      existing.value.isPlaying ? await existing.pause() : await existing.play();
      if (mounted) setState(() {});
      return;
    }

    setState(() {
      _loading = true;
      _failed = false;
    });
    final controller = clip.startsWith('http')
        ? VideoPlayerController.networkUrl(Uri.parse(clip))
        : VideoPlayerController.file(File(clip));
    try {
      await controller.initialize();
      await controller.setLooping(true);
      await controller.play();
    } catch (_) {
      await controller.dispose();
      if (mounted) {
        setState(() {
          _loading = false;
          _failed = true;
        });
      }
      return;
    }
    if (!mounted) {
      await controller.dispose();
      return;
    }
    setState(() {
      _controller = controller;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final playing = controller?.value.isPlaying ?? false;
    final hasClip = widget.person.clip != null;

    return Semantics(
      button: hasClip,
      label: !hasClip
          ? null
          : playing
          ? 'Pause talent clip'
          : 'Play talent clip',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: hasClip ? _toggle : null,
        child: Stack(
          fit: StackFit.expand,
          children: [
            GradientBox(gradient: widget.person.bg),
            if (controller != null)
              FittedBox(
                fit: BoxFit.cover,
                clipBehavior: Clip.hardEdge,
                child: SizedBox(
                  width: controller.value.size.width,
                  height: controller.value.size.height,
                  child: VideoPlayer(controller),
                ),
              ),
            if (!playing)
              Center(
                child: Container(
                  width: 56,
                  height: 56,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: Color(0x66000000),
                    shape: BoxShape.circle,
                  ),
                  child: _loading
                      ? const SizedBox.square(
                          dimension: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : const AppIcon(
                          AppIcons.play,
                          color: Colors.white,
                          filled: true,
                        ),
                ),
              ),
            if (_failed)
              const Align(
                alignment: Alignment(0, 0.45),
                child: Text(
                  "Couldn't play this clip",
                  style: TextStyle(fontSize: 13, color: Colors.white),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SocialIcon extends StatelessWidget {
  const _SocialIcon(this.icon, this.label);

  final String icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return CircleIconButton(
      icon: icon,
      // The design's links have no destinations yet.
      onTap: () {},
      label: label,
      iconSize: 19,
      strokeWidth: 2,
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb(this.gradient);

  final CssGradient gradient;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: AspectRatio(
        aspectRatio: 3 / 4,
        child: GradientBox(
          gradient: gradient,
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}

class _TextAction extends StatelessWidget {
  const _TextAction({
    required this.label,
    required this.color,
    required this.onTap,
  });

  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      label: label,
      builder: (context, _) => SizedBox(
        height: 44,
        child: Center(
          widthFactor: 1,
          child: Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

/// 11 · Settings
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    void toastLabel(String label) => app.showToast(label);
    return ColoredBox(
      color: AppColors.bg,
      child: Padding(
        padding: EdgeInsets.only(top: MediaQuery.paddingOf(context).top),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: CircleIconButton(
                  icon: AppIcons.chevronLeft,
                  onTap: app.closeSub,
                  label: 'Back',
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: 22,
                  children: [
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4),
                      child: Heading('Settings', size: 40),
                    ),
                    _Group('Account', [
                      _Row(
                        'Name',
                        value: app.name,
                        chevron: false,
                        onTap: () => toastLabel('Name'),
                      ),
                      _Row(
                        'Email',
                        value: 'jordan@gmail.com',
                        chevron: false,
                        onTap: () => toastLabel('Email'),
                      ),
                    ]),
                    _Group('Preferences', [
                      _Row(
                        'Push notifications',
                        toggle: app.notifications,
                        onTap: app.toggleNotifications,
                      ),
                      _Row('Privacy', onTap: () => toastLabel('Privacy')),
                    ]),
                    _Group('Safety', [
                      _Row(
                        'Blocked users',
                        value: '${app.blocked.length}',
                        onTap: () => toastLabel('Blocked users'),
                      ),
                      _Row(
                        'Report a problem',
                        onTap: () => toastLabel('Report a problem'),
                      ),
                    ]),
                    _Group('About', [
                      _Row(
                        'Terms & Conditions',
                        onTap: () => toastLabel('Terms & Conditions'),
                      ),
                      _Row(
                        'Privacy Policy',
                        onTap: () => toastLabel('Privacy Policy'),
                      ),
                      _Row(
                        'Contact us',
                        value: 'hello@joincreya.com',
                        onTap: () => toastLabel('Contact us'),
                      ),
                    ]),
                    _Group('Session', [
                      _Row('Sign out', chevron: false, onTap: app.signOut),
                      _Row(
                        'Delete account',
                        chevron: false,
                        color: AppColors.declined,
                        onTap: app.askDeleteAccount,
                      ),
                    ]),
                    const Text(
                      'Creya · v1.0 · joincreya.com',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: AppColors.muted),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group(this.title, this.rows);

  final String title;
  final List<_Row> rows;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 8,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Text(title.toUpperCase(), style: eyebrowStyle),
        ),
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: ColoredBox(
            color: AppColors.card,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < rows.length; i++)
                  DecoratedBox(
                    decoration: BoxDecoration(
                      border: i == 0
                          ? null
                          : const Border(
                              top: BorderSide(color: AppColors.line),
                            ),
                    ),
                    child: rows[i],
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(
    this.label, {
    required this.onTap,
    this.value,
    this.chevron = true,
    this.color = AppColors.text,
    this.toggle,
  });

  final String label;
  final VoidCallback onTap;
  final String? value;
  final bool chevron;
  final Color color;

  /// Non-null renders a switch in that state instead of a chevron.
  final bool? toggle;

  @override
  Widget build(BuildContext context) {
    final on = toggle;
    return Pressable(
      onTap: onTap,
      label: label,
      builder: (context, pressed) => Container(
        constraints: const BoxConstraints(minHeight: 54),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        color: pressed ? const Color(0x0AFFFFFF) : Colors.transparent,
        child: Row(
          spacing: 12,
          children: [
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: color,
                ),
              ),
            ),
            if (value != null)
              Flexible(
                child: Text(
                  value!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14, color: AppColors.muted),
                ),
              ),
            if (on != null)
              Container(
                width: 46,
                height: 28,
                padding: const EdgeInsets.all(3),
                alignment: on ? Alignment.centerRight : Alignment.centerLeft,
                decoration: BoxDecoration(
                  color: on ? AppColors.accent : AppColors.card2,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: on ? Colors.black : Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
              )
            else if (chevron)
              const AppIcon(
                AppIcons.chevronRight,
                color: AppColors.muted,
                size: 16,
              ),
          ],
        ),
      ),
    );
  }
}

/// The "Delete your account?" confirmation sheet.
class DeleteAccountSheet extends StatelessWidget {
  const DeleteAccountSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    return ColoredBox(
      color: const Color(0x99000000),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            margin: EdgeInsets.only(
              bottom: footerInset(context, extra: 0, min: 20),
            ),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(28),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 12,
              children: [
                const Heading(
                  'Delete your ',
                  em: 'account?',
                  size: 30,
                  emColor: AppColors.declined,
                  height: 1.2,
                ),
                const Text(
                  "Your profile, clips, connections and messages are permanently removed. This can't be undone.",
                  style: TextStyle(
                    color: AppColors.muted,
                    fontSize: 15,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 0),
                PillButton(
                  label: 'Delete account',
                  onTap: app.deleteAccount,
                  height: 52,
                  background: AppColors.declined,
                  pressedBackground: AppColors.declined,
                  foreground: Colors.white,
                ),
                PillButton.outline(
                  label: 'Cancel',
                  onTap: app.cancelDelete,
                  height: 52,
                  fontSize: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
