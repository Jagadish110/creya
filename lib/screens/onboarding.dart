import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_state.dart';
import '../icons.dart';
import '../mock_data.dart';
import '../theme.dart';
import '../widgets.dart';

/// 01 · Welcome
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final insets = MediaQuery.paddingOf(context);
    return CustomPaint(
      painter: const _WelcomeGlow(),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          28,
          insets.top + 49,
          28,
          math.max(insets.bottom + 14, 28),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.bg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0x24FFFFFF)),
                  ),
                  child: const Text(
                    'C',
                    style: TextStyle(
                      fontFamily: 'Georgia',
                      fontFamilyFallback: ['serif'],
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: AppColors.text,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                const Wordmark(size: 32),
              ],
            ),
            const Spacer(),
            Text(
              'Where creatives connect'.toUpperCase(),
              style: eyebrowStyle.copyWith(color: AppColors.accent),
            ),
            const SizedBox(height: 16),
            const Heading(
              'Create\n',
              em: 'Together.',
              size: 64,
              height: 0.95,
              letterSpacing: -0.64,
            ),
            const SizedBox(height: 16),
            const Text(
              'Find your creative match. Musicians, visual artists, designers and more.',
              style: TextStyle(
                color: AppColors.muted,
                fontSize: 16,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 40),
            Pressable(
              onTap: app.signIn,
              label: 'Continue with Google',
              builder: (context, pressed) => Container(
                height: 56,
                decoration: BoxDecoration(
                  color: pressed ? const Color(0xFFE8E6EE) : Colors.white,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    GoogleLogo(),
                    SizedBox(width: 12),
                    Text(
                      'Continue with Google',
                      style: TextStyle(
                        color: Color(0xFF111111),
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text.rich(
              const TextSpan(
                text: 'By continuing you agree to our ',
                children: [
                  TextSpan(
                    text: 'Terms',
                    style: TextStyle(color: Colors.white),
                  ),
                  TextSpan(text: ' and '),
                  TextSpan(
                    text: 'Privacy Policy',
                    style: TextStyle(color: Colors.white),
                  ),
                ],
              ),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.muted,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// `radial-gradient(120% 60% at 80% 20%, rgba(255,255,255,.08), transparent 60%)`
class _WelcomeGlow extends CustomPainter {
  const _WelcomeGlow();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = AppColors.bg);
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.translate(size.width * 0.8, size.height * 0.2);
    canvas.scale(size.width * 1.2, size.height * 0.6);
    final unit = Rect.fromCircle(center: Offset.zero, radius: 1);
    canvas.drawRect(
      Rect.fromLTRB(-2, -2, 2, 2),
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0x14FFFFFF), Color(0x00FFFFFF)],
          stops: [0, 0.6],
        ).createShader(unit),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_WelcomeGlow oldDelegate) => false;
}

/// Back button, three-step progress bar and "n / 3" label.
class _StepHeader extends StatelessWidget {
  const _StepHeader({required this.step, required this.onBack});

  final int step;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          CircleIconButton(
            icon: AppIcons.chevronLeft,
            onTap: onBack,
            label: 'Back',
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Row(
              spacing: 6,
              children: [
                for (var i = 1; i <= 3; i++)
                  Expanded(
                    child: Container(
                      height: 4,
                      decoration: BoxDecoration(
                        color: i <= step ? AppColors.accent : AppColors.card2,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 44,
            child: Text(
              '$step / 3',
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 13, color: AppColors.muted),
            ),
          ),
        ],
      ),
    );
  }
}

/// Shared layout for the two form steps.
class _FormStep extends StatelessWidget {
  const _FormStep({
    required this.step,
    required this.onBack,
    required this.title,
    required this.em,
    required this.subtitle,
    required this.footer,
    required this.children,
  });

  final int step;
  final VoidCallback onBack;
  final String title;
  final String em;
  final String subtitle;
  final Widget footer;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: MediaQuery.paddingOf(context).top),
      child: Column(
        children: [
          _StepHeader(step: step, onBack: onBack),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 20,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 6,
                    children: [
                      Heading(title, em: em, size: 44),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                  ...children,
                ],
              ),
            ),
          ),
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(24, 12, 24, footerInset(context)),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.line)),
            ),
            child: footer,
          ),
        ],
      ),
    );
  }
}

/// 02 · Your craft
class CraftScreen extends StatefulWidget {
  const CraftScreen({super.key});

  @override
  State<CraftScreen> createState() => _CraftScreenState();
}

class _CraftScreenState extends State<CraftScreen> {
  final _genreController = TextEditingController();
  final _genreFocus = FocusNode();

  @override
  void dispose() {
    _genreController.dispose();
    _genreFocus.dispose();
    super.dispose();
  }

  void _submitGenre(AppState app) {
    app.addGenre(_genreController.text);
    _genreController.clear();
    _genreFocus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    return _FormStep(
      step: 2,
      onBack: () => app.goToStage(AppStage.welcome),
      title: 'Your ',
      em: 'craft.',
      subtitle: 'Tell other creatives about you.',
      footer: PillButton(
        label: 'Continue',
        onTap: () => app.goToStage(AppStage.face),
      ),
      children: [
        FieldLabel(
          label: const Text('Full name'),
          child: AppTextField(
            initialValue: app.name,
            hint: 'Your name',
            onChanged: (value) => app.updateProfile(name: value),
          ),
        ),
        FieldLabel(
          label: const Text('City'),
          child: AppTextField(
            initialValue: app.city,
            hint: 'Where are you based?',
            onChanged: (value) => app.updateProfile(city: value),
          ),
        ),
        FieldLabel(
          label: const Text('Primary creative'),
          child: AppSelect(
            value: app.creative,
            options: creatives,
            onChanged: (value) => app.updateProfile(creative: value),
          ),
        ),
        FieldLabel(
          label: const Text('Genres · type and press Enter'),
          child: Container(
            constraints: const BoxConstraints(minHeight: 52),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.line),
            ),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                for (final genre in app.genres)
                  _GenreChip(
                    label: genre,
                    onRemove: () => app.removeGenre(genre),
                  ),
                SizedBox(
                  width: 110,
                  height: 32,
                  child: Focus(
                    onKeyEvent: (node, event) {
                      // Hardware-keyboard backspace on an empty field removes
                      // the last chip, as in the design.
                      if (event is KeyDownEvent &&
                          event.logicalKey == LogicalKeyboardKey.backspace &&
                          _genreController.text.isEmpty &&
                          app.genres.isNotEmpty) {
                        app.removeGenre(app.genres.last);
                        return KeyEventResult.handled;
                      }
                      return KeyEventResult.ignored;
                    },
                    child: TextField(
                      controller: _genreController,
                      focusNode: _genreFocus,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _submitGenre(app),
                      style: const TextStyle(fontSize: 15),
                      decoration: const InputDecoration(
                        hintText: 'Add genre',
                        hintStyle: TextStyle(color: AppColors.placeholder),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 7,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        FieldLabel(
          label: const Text('Bio'),
          trailing: '${app.bio.length}/300',
          child: AppTextArea(
            initialValue: app.bio,
            hint: 'What do you make, and who do you want to make it with?',
            onChanged: (value) => app.updateProfile(bio: value),
            maxLength: 300,
            rows: 4,
          ),
        ),
      ],
    );
  }
}

class _GenreChip extends StatelessWidget {
  const _GenreChip({required this.label, required this.onRemove});

  final String label;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onRemove,
      label: 'Remove $label',
      builder: (context, _) => Container(
        height: 32,
        padding: const EdgeInsets.only(left: 12, right: 10),
        decoration: BoxDecoration(
          color: AppColors.accentSoft,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: 6,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.accent,
              ),
            ),
            const AppIcon(
              AppIcons.close,
              color: AppColors.accent,
              size: 12,
              strokeWidth: 3,
            ),
          ],
        ),
      ),
    );
  }
}

/// 03 · Your face
class FaceScreen extends StatelessWidget {
  const FaceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final me = app.me;
    return _FormStep(
      step: 3,
      onBack: () => app.goToStage(AppStage.craft),
      title: 'Your ',
      em: 'face.',
      subtitle: 'A photo and a clip. Show your talent first.',
      footer: PillButton(
        label: 'Create account',
        opacity: app.canCreateAccount ? 1 : 0.4,
        onTap: app.finishOnboarding,
      ),
      children: [
        Row(
          children: [
            Pressable(
              onTap: app.addPhoto,
              label: 'Choose profile photo',
              builder: (context, _) {
                if (app.hasPhoto) {
                  return SizedBox.square(
                    dimension: 96,
                    child: GradientBox(
                      gradient: me.bg,
                      borderRadius: BorderRadius.circular(96),
                      child: Center(
                        child: Text(
                          me.initials,
                          style: const TextStyle(
                            fontFamily: AppFonts.heading,
                            fontWeight: FontWeight.w600,
                            fontSize: 36,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  );
                }
                return const SizedBox.square(
                  dimension: 96,
                  child: DashedBox(
                    color: Color(0x33FFFFFF),
                    radius: 48,
                    background: AppColors.card,
                    child: Center(
                      child: AppIcon(
                        AppIcons.camera,
                        color: AppColors.muted,
                        size: 26,
                        strokeWidth: 2,
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 4,
                children: [
                  const Text.rich(
                    TextSpan(
                      text: 'Profile photo ',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                      children: [
                        TextSpan(
                          text: 'required',
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 13,
                            color: AppColors.accent,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    app.hasPhoto
                        ? 'Looking good. Tap to change.'
                        : 'Tap to choose a photo. This is your creative identity.',
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        FieldLabel(
          label: const Text.rich(
            TextSpan(
              text: 'Talent clip · ',
              children: [
                TextSpan(
                  text: 'required',
                  style: TextStyle(color: AppColors.accent),
                ),
                TextSpan(text: ' · 20s max'),
              ],
            ),
          ),
          child: Pressable(
            onTap: app.uploadClip,
            label: 'Upload talent clip',
            builder: (context, _) => SizedBox(
              height: 150,
              child: DashedBox(
                color: app.clip == ClipStatus.done
                    ? const Color(0x803FCF8E)
                    : const Color(0x33FFFFFF),
                radius: 20,
                background: AppColors.card,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Center(child: _ClipContent(app: app)),
                ),
              ),
            ),
          ),
        ),
        const FieldLabel(
          label: Text('Portfolio URL · optional'),
          child: AppTextField(
            hint: 'yoursite.com',
            keyboardType: TextInputType.url,
          ),
        ),
        const FieldLabel(
          label: Text('Instagram · optional'),
          child: AppTextField(hint: '@handle'),
        ),
      ],
    );
  }
}

class _ClipContent extends StatelessWidget {
  const _ClipContent({required this.app});

  final AppState app;

  static const _title = TextStyle(fontWeight: FontWeight.w600, fontSize: 15);
  static const _caption = TextStyle(color: AppColors.muted, fontSize: 12);

  @override
  Widget build(BuildContext context) {
    final children = switch (app.clip) {
      ClipStatus.idle => const <Widget>[
        AppIcon(
          AppIcons.upload,
          color: AppColors.accent,
          size: 26,
          strokeWidth: 2,
        ),
        Text('Tap to upload your clip', style: _title),
        Text(
          'MP4, MOV · longer clips auto-trimmed to 20s',
          style: _caption,
          textAlign: TextAlign.center,
        ),
      ],
      ClipStatus.uploading => <Widget>[
        Text('Compressing & uploading… ${app.uploadPct}%', style: _title),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: app.uploadPct / 100,
            minHeight: 6,
            backgroundColor: AppColors.card2,
            color: AppColors.accent,
          ),
        ),
        const Text('studio-session.mov · trimmed to 0:20', style: _caption),
      ],
      ClipStatus.done => <Widget>[
        Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: Color(0x293FCF8E),
            shape: BoxShape.circle,
          ),
          child: const AppIcon(
            AppIcons.check,
            color: AppColors.accepted,
            size: 22,
            strokeWidth: 2.5,
          ),
        ),
        const Text('Clip ready · 0:20', style: _title),
        const Text('Tap to replace', style: _caption),
      ],
    };
    return Column(
      mainAxisSize: MainAxisSize.min,
      spacing: 10,
      children: children,
    );
  }
}
