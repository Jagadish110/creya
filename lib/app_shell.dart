import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'app_state.dart';
import 'icons.dart';
import 'screens/collabs.dart';
import 'screens/discover.dart';
import 'screens/messages.dart';
import 'screens/onboarding.dart';
import 'screens/profile.dart';
import 'screens/requests.dart';
import 'theme.dart';

/// Chooses what's on screen and layers overlays above it, mirroring the
/// design's single-stage structure.
class AppShell extends StatelessWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final canExit =
        !app.showDeleteSheet &&
        (app.stage == AppStage.welcome ||
            (app.stage == AppStage.app &&
                app.sub == SubScreen.none &&
                app.tab == AppTab.discover));

    return PopScope(
      canPop: canExit,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) app.handleBack();
      },
      child: Scaffold(
        backgroundColor: AppColors.bg,
        body: Stack(
          fit: StackFit.expand,
          children: [
            switch (app.stage) {
              AppStage.welcome => const WelcomeScreen(),
              AppStage.craft => const CraftScreen(),
              AppStage.face => const FaceScreen(),
              AppStage.app => const _MainApp(),
            },
            if (app.showDeleteSheet) const DeleteAccountSheet(),
            if (app.toastMessage != null) _Toast(message: app.toastMessage!),
          ],
        ),
      ),
    );
  }
}

class _MainApp extends StatelessWidget {
  const _MainApp();

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final insets = MediaQuery.paddingOf(context);
    final showNav = app.sub == SubScreen.none;
    final navHeight = _BottomNav.heightFor(insets.bottom);

    return Stack(
      fit: StackFit.expand,
      children: [
        if (app.tab != AppTab.profile)
          // Kept alive but hidden under full-screen overlays, so scroll
          // position survives without exposing it to screen readers.
          Offstage(
            offstage: !showNav,
            child: Padding(
              padding: EdgeInsets.only(top: insets.top, bottom: navHeight),
              child: switch (app.tab) {
                AppTab.discover => const DiscoverScreen(),
                AppTab.collabs => const CollabsScreen(),
                AppTab.requests => const RequestsScreen(),
                AppTab.messages => const MessagesScreen(),
                AppTab.profile => const SizedBox.shrink(),
              },
            ),
          ),
        if (app.tab == AppTab.profile && app.sub == SubScreen.none)
          Padding(
            padding: EdgeInsets.only(bottom: navHeight),
            child: const ProfileScreen(),
          ),
        if (app.sub == SubScreen.person) const ProfileScreen(),
        if (app.sub == SubScreen.post) const PostCollabScreen(),
        if (app.sub == SubScreen.chat) const ChatScreen(),
        if (app.sub == SubScreen.settings) const SettingsScreen(),
        if (showNav)
          const Positioned(left: 0, right: 0, bottom: 0, child: _BottomNav()),
      ],
    );
  }
}

class _BottomNav extends StatelessWidget {
  const _BottomNav();

  static const _contentHeight = 50.0;
  static const _topPadding = 4.0;

  /// 84pt on a phone with a home indicator, as in the design.
  static double _bottomPadding(double inset) => math.max(inset - 4, 8);

  static double heightFor(double inset) =>
      _topPadding + _contentHeight + _bottomPadding(inset);

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final inset = MediaQuery.paddingOf(context).bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(
        8,
        _topPadding,
        8,
        _bottomPadding(inset),
      ),
      decoration: const BoxDecoration(
        color: AppColors.navBg,
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      child: SizedBox(
        height: _contentHeight,
        child: Row(
          children: [
            _NavItem(AppTab.discover, AppIcons.compass, 'Discover'),
            _NavItem(AppTab.collabs, AppIcons.layers, 'Collabs'),
            _NavItem(
              AppTab.requests,
              AppIcons.inbox,
              'Requests',
              badge: app.requestBadge,
            ),
            _NavItem(AppTab.messages, AppIcons.message, 'Messages'),
            _NavItem(AppTab.profile, AppIcons.user, 'Profile'),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem(this.tab, this.icon, this.label, {this.badge = 0});

  final AppTab tab;
  final String icon;
  final String label;
  final int badge;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final selected = app.tab == tab;
    final color = selected ? AppColors.accent : AppColors.muted;
    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        label: badge > 0 ? '$label, $badge pending' : label,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => app.selectTab(tab),
          child: LayoutBuilder(
            builder: (context, constraints) => Stack(
              fit: StackFit.expand,
              children: [
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AppIcon(icon, color: color, size: 24, strokeWidth: 2),
                    const SizedBox(height: 5),
                    Opacity(
                      opacity: selected ? 1 : 0,
                      child: Container(
                        width: 4,
                        height: 4,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ],
                ),
                if (badge > 0)
                  Positioned(
                    top: 2,
                    left: constraints.maxWidth / 2 + 4,
                    child: Container(
                      constraints: const BoxConstraints(minWidth: 18),
                      height: 18,
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.accent,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: AppColors.bg, width: 2),
                      ),
                      child: Text(
                        '$badge',
                        style: const TextStyle(
                          color: AppColors.onAccent,
                          fontSize: 11,
                          height: 1,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Toast extends StatelessWidget {
  const _Toast({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 16,
      right: 16,
      top: MediaQuery.paddingOf(context).top + 9,
      child: IgnorePointer(
        child: Semantics(
          liveRegion: true,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.card2,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0x1FFFFFFF)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x80000000),
                  blurRadius: 40,
                  offset: Offset(0, 12),
                ),
              ],
            ),
            child: Row(
              spacing: 10,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.accent,
                    shape: BoxShape.circle,
                  ),
                ),
                Expanded(
                  child: Text(
                    message,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
