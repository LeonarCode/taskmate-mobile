import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../core/ui_helpers.dart';
import '../models/message_model.dart';
import '../models/user_model.dart';
import '../providers/auth_provider.dart';
import '../providers/chat_thread_controller.dart';
import 'common.dart';
import 'message_bubble.dart';
import 'user_avatar.dart';

/// Messages list plus the input bar for one conversation. Used by both the
/// direct chat and the server chat; [controller] holds the data.
class ChatThreadView extends StatefulWidget {
  const ChatThreadView({
    super.key,
    required this.controller,
    required this.emptyText,
    required this.inputHint,
    this.partner,
  });

  final ChatThreadController controller;
  final String emptyText;
  final String inputHint;

  /// The other person in a direct chat; null for a server chat, where each
  /// message carries its own sender.
  final UserPublic? partner;

  @override
  State<ChatThreadView> createState() => _ChatThreadViewState();
}

class _ChatThreadViewState extends State<ChatThreadView> {
  final _inputCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _sending = false;

  ChatThreadController get _thread => widget.controller;

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_maybeLoadOlder);
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    _inputCtrl.dispose();
    super.dispose();
  }

  // The list is reversed, so its "end" is the oldest message.
  void _maybeLoadOlder() {
    if (!_scrollCtrl.hasClients) return;
    final position = _scrollCtrl.position;
    if (position.pixels >= position.maxScrollExtent - 300) {
      _thread.loadOlder();
    }
  }

  void _scrollToLatest() {
    if (!_scrollCtrl.hasClients) return;
    _scrollCtrl.animateTo(
      0,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  Future<void> _send() async {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty || _sending) return;
    _inputCtrl.clear();
    setState(() => _sending = true);
    try {
      await _thread.send(text);
      _scrollToLatest();
    } catch (e) {
      _inputCtrl.text = text; // give the text back so nothing is lost
      if (mounted) showErrorSnack(context, e);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        Expanded(
          child: ListenableBuilder(
            listenable: _thread,
            builder: (context, _) => _buildMessages(context, isDark),
          ),
        ),
        _buildInput(isDark),
      ],
    );
  }

  Widget _buildMessages(BuildContext context, bool isDark) {
    if (_thread.isLoading) return const BrandSpinner();

    final messages = _thread.messages;
    if (messages.isEmpty) {
      if (_thread.error != null) {
        return EmptyState(
          icon: Icons.cloud_off_rounded,
          message: '${_thread.error}\n\nTap to try again.',
          onTap: _thread.load,
        );
      }
      return Center(
        child: Text(
          widget.emptyText,
          style: TextStyle(
            color: isDark ? AppColors.gray400 : AppColors.gray500,
            fontSize: 15,
          ),
        ),
      );
    }

    final me = context.read<AuthProvider>().userModel!;
    // Newest first, because the list is reversed (newest at the bottom).
    final newestFirst = messages.reversed.toList();
    // Direct chats show "Seen" under the last message I sent, once it was read.
    int? lastSeenId;
    if (widget.partner != null) {
      final mine = messages.where((m) => m.senderId == _thread.myId);
      if (mine.isNotEmpty && mine.last.isRead) lastSeenId = mine.last.id;
    }

    return ListView.builder(
      controller: _scrollCtrl,
      reverse: true,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: newestFirst.length + (_thread.isLoadingOlder ? 1 : 0),
      itemBuilder: (context, i) {
        if (i == newestFirst.length) {
          return const Padding(
            padding: EdgeInsets.all(12),
            child: SizedBox(height: 24, child: BrandSpinner()),
          );
        }
        final message = newestFirst[i];
        final isMe = message.senderId == _thread.myId;
        final sender = message.sender ?? widget.partner;
        return MessageBubble(
          message: message,
          isMe: isMe,
          senderName: isMe ? me.fullName : (sender?.fullName ?? ''),
          avatar: isMe
              ? UserAvatar.me(me, radius: 16)
              : (sender != null
                    ? UserAvatar.of(sender, radius: 16)
                    : const UserAvatar(name: '?', radius: 16)),
          showSenderName: widget.partner == null,
          showSeen: message.id == lastSeenId,
          onLongPress: isMe && message.type == MessageType.text
              ? () => _showMessageMenu(message)
              : null,
        );
      },
    );
  }

  Widget _buildInput(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? AppColors.dark800 : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? AppColors.dark600 : AppColors.gray200,
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              // Enter sends; on mobile the keyboard's send button does.
              child: CallbackShortcuts(
                bindings: {
                  const SingleActivator(LogicalKeyboardKey.enter): _send,
                },
                child: TextField(
                  controller: _inputCtrl,
                  minLines: 1,
                  maxLines: 4,
                  maxLength: 4000,
                  buildCounter:
                      (
                        _, {
                        required currentLength,
                        required isFocused,
                        maxLength,
                      }) => null,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _send(),
                  style: TextStyle(
                    color: isDark ? Colors.white : AppColors.gray900,
                    fontSize: 14,
                  ),
                  decoration: InputDecoration(
                    hintText: widget.inputHint,
                    fillColor: isDark ? AppColors.dark700 : AppColors.gray50,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    border: _pill,
                    enabledBorder: _pill,
                    focusedBorder: _pill,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _send,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.send_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static final _pill = OutlineInputBorder(
    borderRadius: BorderRadius.circular(24),
    borderSide: BorderSide.none,
  );

  // ── Edit / delete ────────────────────────────────────────────────────────────
  Future<void> _showMessageMenu(MessageModel message) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        decoration: BoxDecoration(
          color: isDark ? AppColors.dark800 : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SheetHandle(bottomMargin: 16),
              ListTile(
                leading: const Icon(
                  Icons.edit_rounded,
                  color: AppColors.purple600,
                ),
                title: const Text('Edit message'),
                onTap: () => Navigator.pop(sheetContext, 'edit'),
              ),
              ListTile(
                leading: const Icon(
                  Icons.delete_rounded,
                  color: AppColors.red500,
                ),
                title: const Text(
                  'Delete message',
                  style: TextStyle(color: AppColors.red500),
                ),
                onTap: () => Navigator.pop(sheetContext, 'delete'),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted || action == null) return;
    if (action == 'edit') await _editMessage(message);
    if (action == 'delete') await _deleteMessage(message);
  }

  Future<void> _editMessage(MessageModel message) async {
    final ctrl = TextEditingController(text: message.content);
    final text = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit message'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLines: 5,
          minLines: 1,
          maxLength: 4000,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, ctrl.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (text == null || text.isEmpty || text == message.content) return;
    try {
      await _thread.edit(message, text);
    } catch (e) {
      if (mounted) showErrorSnack(context, e);
    }
  }

  Future<void> _deleteMessage(MessageModel message) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete message'),
        content: const Text('Delete this message for everyone?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.red500),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _thread.remove(message);
    } catch (e) {
      if (mounted) showErrorSnack(context, e);
    }
  }
}
