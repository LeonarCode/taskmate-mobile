import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/ui_helpers.dart';
import '../../models/message_model.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../../services/user_service.dart';
import '../../widgets/common.dart';
import '../../widgets/user_avatar.dart';
import 'chat_detail_screen.dart';

class ChatsScreen extends StatefulWidget {
  const ChatsScreen({super.key});

  @override
  State<ChatsScreen> createState() => _ChatsScreenState();
}

class _ChatsScreenState extends State<ChatsScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<ConversationModel> _filtered(List<ConversationModel> all) {
    if (_query.isEmpty) return all;
    return all.where((c) {
      return c.partner.fullName.toLowerCase().contains(_query) ||
          c.partner.username.toLowerCase().contains(_query) ||
          c.lastMessage.preview.toLowerCase().contains(_query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final chat = context.watch<ChatProvider>();
    final myId = context.watch<AuthProvider>().userModel?.id ?? 0;
    final conversations = _filtered(chat.conversations);

    return Scaffold(
      backgroundColor: isDark ? AppColors.dark900 : AppColors.gray50,
      appBar: AppBar(
        title: const Text('Direct Messages'),
        backgroundColor: isDark ? AppColors.dark900 : AppColors.gray50,
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_rounded),
            tooltip: 'New chat',
            onPressed: () => _showSearchUser(context),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
              decoration: InputDecoration(
                hintText: 'Search chats...',
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: AppColors.purple600,
                ),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _query = '');
                        },
                      )
                    : null,
              ),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              color: AppColors.purple600,
              onRefresh: chat.refresh,
              child: _buildList(chat, conversations, myId, isDark),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList(
    ChatProvider chat,
    List<ConversationModel> conversations,
    int myId,
    bool isDark,
  ) {
    if (chat.isLoading && chat.conversations.isEmpty) {
      return const BrandSpinner();
    }

    if (conversations.isEmpty) {
      // Scrollable so pull-to-refresh also works on the empty state.
      return LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SizedBox(
            height: constraints.maxHeight,
            child: chat.error != null && chat.conversations.isEmpty
                ? EmptyState(
                    icon: Icons.cloud_off_rounded,
                    message: chat.error!,
                  )
                : EmptyState(
                    icon: Icons.chat_rounded,
                    message: _query.isEmpty
                        ? 'No direct messages yet.\nTap the icon to start chatting!'
                        : 'No chats match "$_query".',
                  ),
          ),
        ),
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: conversations.length,
      itemBuilder: (_, i) =>
          _ConversationTile(conversation: conversations[i], myId: myId),
    );
  }

  void _showSearchUser(BuildContext context) {
    showAppSheet<void>(context, (_) => const _UserSearchSheet());
  }
}

// ── Conversation tile ──────────────────────────────────────────────────────────
class _ConversationTile extends StatelessWidget {
  final ConversationModel conversation;
  final int myId;

  const _ConversationTile({required this.conversation, required this.myId});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final partner = conversation.partner;
    final last = conversation.lastMessage;
    final unread = conversation.unreadCount;
    final preview = last.senderId == myId
        ? 'You: ${last.preview}'
        : last.preview;

    return GestureDetector(
      onTap: () => openChat(context, partner),
      child: Container(
        color: Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Stack(
              children: [
                UserAvatar.of(partner, radius: 26),
                if (unread > 0)
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: const BoxDecoration(
                        color: AppColors.red500,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          unread > 9 ? '9+' : '$unread',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    partner.fullName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: unread > 0
                          ? FontWeight.w700
                          : FontWeight.w600,
                      color: isDark ? Colors.white : AppColors.gray900,
                    ),
                  ),
                  Text(
                    preview,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: unread > 0
                          ? FontWeight.w600
                          : FontWeight.w400,
                      color: isDark ? AppColors.gray400 : AppColors.gray500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              shortTimeLabel(last.createdAt),
              style: TextStyle(
                fontSize: 11,
                color: isDark ? AppColors.gray500 : AppColors.gray400,
                fontWeight: unread > 0 ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Opens the chat with [partner].
void openChat(BuildContext context, UserPublic partner) {
  Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => ChatDetailScreen(partner: partner)),
  );
}

// ── User search sheet ──────────────────────────────────────────────────────────
class _UserSearchSheet extends StatefulWidget {
  const _UserSearchSheet();

  @override
  State<_UserSearchSheet> createState() => _UserSearchSheetState();
}

class _UserSearchSheetState extends State<_UserSearchSheet> {
  final _ctrl = TextEditingController();
  Timer? _debounce;
  List<UserPublic> _results = [];
  bool _loading = false;
  String? _error;
  String _lastQuery = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    final query = value.trim();
    if (query.isEmpty) {
      setState(() {
        _results = [];
        _loading = false;
        _error = null;
        _lastQuery = '';
      });
      return;
    }
    setState(() => _loading = true);
    _debounce = Timer(const Duration(milliseconds: 350), () => _search(query));
  }

  Future<void> _search(String query) async {
    try {
      final results = await context.read<UserService>().search(query);
      if (!mounted || _ctrl.text.trim() != query) return;
      setState(() {
        _results = results;
        _error = null;
        _lastQuery = query;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || _ctrl.text.trim() != query) return;
      setState(() {
        _error = errorText(e);
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SheetContainer(
      height: MediaQuery.of(context).size.height * 0.75,
      child: Column(
        children: [
          const SheetHandle(),
          TextField(
            controller: _ctrl,
            onChanged: _onChanged,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'Search by username...',
              prefixIcon: Icon(
                Icons.search_rounded,
                color: AppColors.purple600,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(child: _buildResults(isDark)),
        ],
      ),
    );
  }

  Widget _buildResults(bool isDark) {
    if (_loading) return const BrandSpinner();
    if (_error != null) {
      return Center(
        child: Text(_error!, style: const TextStyle(color: AppColors.red500)),
      );
    }
    if (_results.isEmpty) {
      return Center(
        child: Text(
          _lastQuery.isEmpty
              ? 'Type a username to find someone.'
              : 'No users found.',
          style: TextStyle(
            color: isDark ? AppColors.gray400 : AppColors.gray500,
          ),
        ),
      );
    }
    return ListView.builder(
      itemCount: _results.length,
      itemBuilder: (_, i) {
        final user = _results[i];
        return ListTile(
          leading: UserAvatar.of(user),
          title: Text(
            user.fullName,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : AppColors.gray900,
            ),
          ),
          subtitle: Text(
            '@${user.username}',
            style: TextStyle(
              color: isDark ? AppColors.gray400 : AppColors.gray500,
            ),
          ),
          trailing: const Icon(Icons.chat_rounded, color: AppColors.purple600),
          onTap: () {
            final navigator = Navigator.of(context);
            navigator.pop();
            navigator.push(
              MaterialPageRoute(
                builder: (_) => ChatDetailScreen(partner: user),
              ),
            );
          },
        );
      },
    );
  }
}
