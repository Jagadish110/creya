import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app_state.dart';
import '../icons.dart';
import '../mock_data.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets.dart';

/// 05 · Collabs
class CollabsScreen extends StatelessWidget {
  const CollabsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final showingBrowse = app.collabMode == CollabMode.browse;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Heading('Collabs', size: 38),
              PillButton(
                label: '+ Post',
                onTap: app.openNewPost,
                height: 44,
                fontSize: 14,
                padding: const EdgeInsets.symmetric(horizontal: 18),
              ),
            ],
          ),
        ),
        Segments(
          left: 'Browse',
          right: 'My posts · ${app.myPostCount}',
          leftSelected: showingBrowse,
          onLeft: () => app.setCollabMode(CollabMode.browse),
          onRight: () => app.setCollabMode(CollabMode.mine),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            child: _body(app, showingBrowse),
          ),
        ),
      ],
    );
  }

  Widget _body(AppState app, bool showingBrowse) {
    switch (app.listState) {
      case ListState.loading:
        return const Column(
          spacing: 14,
          children: [
            SkeletonCard(height: 290),
            SkeletonCard(height: 200, opacity: 0.6),
          ],
        );
      case ListState.error:
        return LoadError(onRetry: app.retry);
      case ListState.data:
      case ListState.empty:
        break;
    }
    final isEmpty = showingBrowse ? app.browse.isEmpty : app.mine.isEmpty;
    if (isEmpty) {
      return MessageBlock(
        title: 'Nothing ',
        em: 'here yet.',
        body: showingBrowse
            ? 'No collabs match right now. Be the first to post one.'
            : 'You haven’t posted a collab yet.',
        action: PillButton(
          label: 'Post a collab',
          onTap: app.openNewPost,
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 22),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 14,
      children: showingBrowse
          ? [for (final c in app.browse) _CollabCard(collab: c)]
          : [for (final m in app.mine) _MyPostCard(post: m)],
    );
  }
}

class _CollabCard extends StatelessWidget {
  const _CollabCard({required this.collab});

  final Collab collab;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final owner = collab.owner;
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: ColoredBox(
        color: AppColors.card,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (collab.media == CollabMedia.clip)
              _ClipPreview(gradient: CssGradient.fromHue(owner.hue, 20))
            else
              const _AudioPreview(),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 10,
                children: [
                  Tag(label: 'Looking for · ${collab.skill}'),
                  Text(
                    collab.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                    ),
                  ),
                  Text(
                    collab.desc,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 14,
                      height: 1.45,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      spacing: 10,
                      children: [
                        Avatar(person: owner, size: 36, fontSize: 13),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                owner.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                '${owner.creative} · ${collab.time}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (collab.applied)
                          PillButton.outline(
                            label: 'Applied',
                            onTap: null,
                            height: 44,
                            foreground: AppColors.muted,
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                          )
                        else
                          PillButton(
                            label: 'Apply',
                            onTap: () => app.apply(collab),
                            height: 44,
                            fontSize: 14,
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ClipPreview extends StatelessWidget {
  const _ClipPreview({required this.gradient});

  final CssGradient gradient;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 170,
      child: GradientBox(
        gradient: gradient,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Center(
              child: Container(
                width: 52,
                height: 52,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: Color(0x73000000),
                  shape: BoxShape.circle,
                ),
                child: const AppIcon(
                  AppIcons.play,
                  color: Colors.white,
                  filled: true,
                ),
              ),
            ),
            Positioned(
              right: 12,
              bottom: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0x80000000),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  '0:08',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AudioPreview extends StatelessWidget {
  const _AudioPreview();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 96,
      color: AppColors.card2,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Row(
        spacing: 14,
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppColors.accent,
              shape: BoxShape.circle,
            ),
            // The design has a white triangle on this white circle, which
            // can't be seen, so the icon uses the on-accent colour instead.
            child: const AppIcon(
              AppIcons.play,
              color: AppColors.onAccent,
              size: 16,
              filled: true,
            ),
          ),
          const Expanded(
            child: SizedBox(
              height: 44,
              child: CustomPaint(painter: _WavePainter()),
            ),
          ),
          const Text(
            '0:10',
            style: TextStyle(fontSize: 12, color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}

class _WavePainter extends CustomPainter {
  const _WavePainter();

  static const _barCount = 42;
  static const _gap = 3.0;
  static const _playedBars = 14;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.clipRect(Offset.zero & size);
    final barWidth = math.max(
      2.0,
      (size.width - _gap * (_barCount - 1)) / _barCount,
    );
    final played = Paint()..color = AppColors.accent;
    final rest = Paint()..color = const Color(0x38FFFFFF);
    for (var i = 0; i < _barCount; i++) {
      final percent = (20 + 70 * (math.sin(i * 0.7) * math.cos(i * 0.23)).abs())
          .roundToDouble();
      final height = size.height * percent / 100;
      final rect = Rect.fromLTWH(
        i * (barWidth + _gap),
        (size.height - height) / 2,
        barWidth,
        height,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(2)),
        i < _playedBars ? played : rest,
      );
    }
  }

  @override
  bool shouldRepaint(_WavePainter oldDelegate) => false;
}

class _MyPostCard extends StatelessWidget {
  const _MyPostCard({required this.post});

  final MyPost post;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final applicants = app.applicantsFor(post);
    final pending = applicants > 0;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 12,
        children: [
          Row(
            spacing: 8,
            children: [
              Flexible(child: Tag(label: post.skill)),
              Tag(
                label: pending ? 'Pending' : 'Open',
                dot: true,
                background: pending
                    ? const Color(0x24F5B544)
                    : const Color(0x243FCF8E),
                foreground: pending ? AppColors.pending : AppColors.accepted,
              ),
              const Spacer(),
              Text(
                post.time,
                style: const TextStyle(fontSize: 12, color: AppColors.muted),
              ),
            ],
          ),
          Text(
            post.title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              height: 1.3,
            ),
          ),
          Row(
            spacing: 8,
            children: [
              Expanded(
                child: PillButton(
                  label: pending
                      ? 'View applicants · $applicants'
                      : 'No applicants yet',
                  onTap: app.viewApplicants,
                  height: 44,
                  fontSize: 14,
                ),
              ),
              PillButton.outline(
                label: 'Edit',
                onTap: () => app.editPost(post),
                height: 44,
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              PillButton.outline(
                label: 'Delete',
                onTap: () => app.deletePost(post),
                height: 44,
                foreground: AppColors.declined,
                border: const BorderSide(color: Color(0x66F26D6D)),
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 06 · Post a collab
class PostCollabScreen extends StatelessWidget {
  const PostCollabScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    return ColoredBox(
      color: AppColors.bg,
      child: Padding(
        padding: EdgeInsets.only(top: MediaQuery.paddingOf(context).top),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CircleIconButton(
                    icon: AppIcons.close,
                    onTap: app.closeSub,
                    label: 'Close',
                    strokeWidth: 2.5,
                  ),
                  const Text(
                    'Visible to all creatives',
                    style: TextStyle(fontSize: 13, color: AppColors.muted),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: 20,
                  children: [
                    const Heading('Post a ', em: 'collab.', size: 44),
                    FieldLabel(
                      label: const Text('Title'),
                      trailing: '${app.postTitle.length}/80',
                      child: AppTextField(
                        initialValue: app.postTitle,
                        hint: 'e.g. Vocalist for a summer house single',
                        maxLength: 80,
                        onChanged: (v) => app.updatePostDraft(title: v),
                      ),
                    ),
                    FieldLabel(
                      label: const Text("I'm looking for"),
                      child: AppSelect(
                        value: app.postSkill,
                        options: creatives,
                        onChanged: (v) => app.updatePostDraft(skill: v),
                      ),
                    ),
                    FieldLabel(
                      label: const Text('Description'),
                      trailing: '${app.postDesc.length}/400',
                      child: AppTextArea(
                        initialValue: app.postDesc,
                        hint: "What's the project, the vibe, the timeline?",
                        maxLength: 400,
                        rows: 5,
                        onChanged: (v) => app.updatePostDraft(desc: v),
                      ),
                    ),
                    const FieldLabel(
                      label: Text('Clip · optional · 10s max'),
                      child: SizedBox(
                        height: 96,
                        child: DashedBox(
                          color: AppColors.line,
                          radius: 20,
                          background: AppColors.card,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            spacing: 10,
                            children: [
                              AppIcon(
                                AppIcons.upload,
                                color: AppColors.accent,
                                size: 22,
                                strokeWidth: 2,
                              ),
                              Text(
                                'Attach a clip',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
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
              child: PillButton(
                label: app.editingPostId != null ? 'Save changes' : 'Publish',
                opacity: app.canPublish ? 1 : 0.4,
                onTap: app.publishPost,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
