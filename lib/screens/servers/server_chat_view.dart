import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_thread_controller.dart';
import '../../services/message_service.dart';
import '../../services/realtime_service.dart';
import '../../widgets/chat_thread_view.dart';

/// The chat tab of a server.
class ServerChatView extends StatefulWidget {
  final int serverId;
  const ServerChatView({super.key, required this.serverId});

  @override
  State<ServerChatView> createState() => _ServerChatViewState();
}

class _ServerChatViewState extends State<ServerChatView> {
  late final ServerThreadController _thread;

  @override
  void initState() {
    super.initState();
    _thread = ServerThreadController(
      context.read<RealtimeService>(),
      myId: context.read<AuthProvider>().userModel!.id,
      serverId: widget.serverId,
      service: context.read<MessageService>(),
    )..load();
  }

  @override
  void dispose() {
    _thread.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChatThreadView(
      controller: _thread,
      emptyText: 'Be the first to say hello!',
      inputHint: 'Message server...',
    );
  }
}
