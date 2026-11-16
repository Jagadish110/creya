import 'package:flutter/material.dart';

import '../app_state.dart';
import '../icons.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets.dart';

/// 08 · Messages
class MessagesScreen extends StatelessWidget {
  const MessagesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 12, 20, 10),
          child: Heading('Messages', size: 38),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
            child: _body(app),
          ),
        ),
      ],
    );
  }

  Widget _body(AppState app) {
    switch (app.listState) {
      case ListState.loading:
        return const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: Column(
            spacing: 4,
            children: [
              _SkeletonRow(),
              _SkeletonRow(),
              _SkeletonRow(),
              _SkeletonRow(),
            ],
          ),
        );
      case ListState.error:
        return LoadError(onRetry: app.retry);
      case ListState.data:
      case ListState.empty:
        break;
    }
    final chats = app.chats;
    if (chats.isEmpty) {
      return MessageBlock(
        title: 'Your ',
        em: 'messages.',
        body: 'Accept a connection request to start a conversation.',
        vertical: 80,
        icon: Container(
          width: 64,
          height: 64,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: AppColors.accentSoft,
            shape: BoxShape.circle,
          ),
          child: const AppIcon(
            AppIcons.message,
            color: AppColors.accent,
            size: 26,
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [for (final chat in chats) _ChatRow(chat: chat)],
    );
  }
}

class _SkeletonRow extends StatelessWidget {
  const _SkeletonRow();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        spacing: 12,
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: const BoxDecoration(
              color: AppColors.card,
              shape: BoxShape.circle,
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 8,
              children: [
                FractionallySizedBox(
                  widthFactor: 0.4,
                  child: Container(
                    height: 12,
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: 0.75,
                  child: Container(
                    height: 10,
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatRow extends StatelessWidget {
  const _ChatRow({required this.chat});

  final Chat chat;

  String get _preview {
    if (chat.messages.isEmpty) return 'You’re connected. Say hello.';
    final last = chat.messages.last;
    return '${last.me ? 'You: ' : ''}${last.body}';
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final person = chat.person;
    return Pressable(
      onTap: () => app.openChat(chat),
      label: 'Chat with ${person.name}',
      builder: (context, pressed) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: pressed ? AppColors.card : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          spacing: 12,
          children: [
            Avatar(person: person, size: 54, fontSize: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 3,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    spacing: 8,
                    children: [
                      Flexible(
                        child: Text(
                          person.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Text(
                        chat.time,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    spacing: 8,
                    children: [
                      Expanded(
                        child: Text(
                          _preview,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            color: chat.unread
                                ? AppColors.text
                                : AppColors.muted,
                          ),
                        ),
                      ),
                      Opacity(
                        opacity: chat.unread ? 1 : 0,
                        child: Container(
                          width: 9,
                          height: 9,
                          decoration: const BoxDecoration(
                            color: AppColors.accent,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ],
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

/// 09 · Chat
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _draft = TextEditingController();
  final _focus = FocusNode();
  final _scroll = ScrollController();

  @override
  void dispose() {
    _draft.dispose();
    _focus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _send(AppState app) {
    app.sendMessage(_draft.text);
    // Offset 0 is the newest message, since the list is reversed.
    if (_scroll.hasClients) _scroll.jumpTo(0);
    _draft.clear();
    _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final chat = app.activeChat;
    if (chat == null) return const SizedBox.shrink();
    final person = chat.person;

    return ColoredBox(
      color: AppColors.bg,
      child: Padding(
        padding: EdgeInsets.only(top: MediaQuery.paddingOf(context).top),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.line)),
              ),
              child: Row(
                spacing: 12,
                children: [
                  CircleIconButton(
                    icon: AppIcons.chevronLeft,
                    onTap: app.closeSub,
                    label: 'Back',
                  ),
                  Expanded(
                    child: Pressable(
                      onTap: () => app.openPerson(person),
                      label: 'View ${person.name}',
                      builder: (context, _) => Row(
                        spacing: 10,
                        children: [
                          Avatar(person: person, size: 40, fontSize: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  person.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                  ),
                                ),
                                Text(
                                  app.typing ? 'typing…' : person.creative,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final maxBubble = (constraints.maxWidth - 32) * 0.78;
                  // Reversed, so the newest message stays in view as messages
                  // arrive and earlier pages can be added above without the
                  // view jumping. The minimum height keeps a short chat at
                  // the top of the screen.
                  return NotificationListener<ScrollNotification>(
                    onNotification: (scroll) {
                      if (scroll.metrics.extentAfter < 200) {
                        app.loadOlderMessages();
                      }
                      return false;
                    },
                    child: SingleChildScrollView(
                      controller: _scroll,
                      reverse: true,
                      padding: const EdgeInsets.all(16),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight - 32,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          spacing: 6,
                          children: [
                            if (app.loadingOlder)
                              const Padding(
                                padding: EdgeInsets.only(bottom: 8),
                                child: Center(
                                  child: SizedBox.square(
                                    dimension: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppColors.muted,
                                    ),
                                  ),
                                ),
                              ),
                            if (chat.historyLoaded && !chat.hasOlder)
                              Center(
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.card,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: const Text(
                                    'You connected · say hello',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.muted,
                                    ),
                                  ),
                                ),
                              ),
                            for (final message in chat.messages)
                              _Bubble(message: message, maxWidth: maxBubble),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            Container(
              padding: EdgeInsets.fromLTRB(
                12,
                10,
                12,
                footerInset(context, extra: 0, min: 12),
              ),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.line)),
              ),
              child: Row(
                spacing: 8,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _draft,
                      focusNode: _focus,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(app),
                      style: const TextStyle(fontSize: 15, height: 1.333),
                      decoration: InputDecoration(
                        hintText: 'Message',
                        hintStyle: const TextStyle(
                          color: AppColors.placeholder,
                        ),
                        filled: true,
                        fillColor: AppColors.card,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 14,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(999),
                          borderSide: const BorderSide(color: AppColors.line),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(999),
                          borderSide: const BorderSide(color: AppColors.accent),
                        ),
                      ),
                    ),
                  ),
                  CircleIconButton(
                    icon: AppIcons.send,
                    onTap: () => _send(app),
                    label: 'Send',
                    size: 48,
                    iconSize: 19,
                    background: AppColors.accent,
                    foreground: AppColors.onAccent,
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

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message, required this.maxWidth});

  final Message message;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: message.me ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: maxWidth),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: message.me ? AppColors.accent : AppColors.card2,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          message.body,
          style: TextStyle(
            color: message.me ? Colors.black : Colors.white,
            fontSize: 15,
            height: 1.4,
          ),
        ),
      ),
    );
  }
}
