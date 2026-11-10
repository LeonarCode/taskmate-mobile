import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../../providers/chat_thread_controller.dart';
import '../../services/message_service.dart';
import '../../services/realtime_service.dart';
import '../../widgets/chat_thread_view.dart';
import '../../widgets/user_avatar.dart';

/// A one-to-one conversation.
class ChatDetailScreen extends StatefulWidget {
  final UserPublic partner;

  const ChatDetailScreen({super.key, required this.partner});

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  late final ChatProvider _chats;
  late final DirectThreadController _thread;

  @override
  void initState() {
    super.initState();
    _chats = context.read<ChatProvider>();
    _thread = DirectThreadController(
      context.read<RealtimeService>(),
      myId: context.read<AuthProvider>().userModel!.id,
      partner: widget.partner,
      service: context.read<MessageService>(),
      onRead: () => _chats.markReadLocally(widget.partner.id),
    )..load();
  }

  @override
  void dispose() {
    _thread.dispose();
    // The Chats tab shows the last message; bring it up to date.
    _chats.refresh();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final partner = widget.partner;
    return Scaffold(
      backgroundColor: isDark ? AppColors.dark900 : AppColors.gray50,
      appBar: AppBar(
        backgroundColor: isDark ? AppColors.dark800 : Colors.white,
        title: Row(
          children: [
            UserAvatar.of(partner, radius: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    partner.fullName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    '@${partner.username}',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? AppColors.gray400 : AppColors.gray500,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: ChatThreadView(
        controller: _thread,
        partner: partner,
        emptyText: 'Say hello to ${partner.fullName.split(' ').first}! 👋',
        inputHint: 'Message...',
      ),
    );
  }
}
