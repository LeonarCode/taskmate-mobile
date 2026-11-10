import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/message_model.dart';
import '../models/user_model.dart';
import '../services/api_client.dart';
import '../services/message_service.dart';
import '../services/realtime_service.dart';

/// The messages of one open conversation (a direct chat or a server chat):
/// loads the latest page, older pages on demand, and applies the live events
/// the backend pushes for it. Sending goes through REST (so the backend can
/// validate); the backend then pushes the message to everyone else.
abstract class ChatThreadController extends ChangeNotifier {
  ChatThreadController(RealtimeService realtime, {required this.myId}) {
    _events = realtime.events.listen(_onRealtimeEvent);
  }

  static const pageSize = 50;

  final int myId;
  late final StreamSubscription<RealtimeEvent> _events;
  bool _disposed = false;

  /// Oldest first.
  List<MessageModel> _messages = [];
  bool _isLoading = true;
  bool _isLoadingOlder = false;
  bool _hasMore = true;
  String? _error;

  List<MessageModel> get messages => _messages;
  bool get isLoading => _isLoading;
  bool get isLoadingOlder => _isLoadingOlder;
  bool get hasMore => _hasMore;
  String? get error => _error;

  // ── What each kind of conversation provides ──────────────────────────────────
  Future<List<MessageModel>> fetchPage({int? beforeId});
  Future<MessageModel> sendText(String content);
  Future<MessageModel> editText(int id, String content);
  Future<void> deleteMessage(int id);

  /// Applies a realtime event that belongs to this conversation.
  @protected
  void handleEvent(RealtimeEvent event);

  /// Called after messages from the other side were added or loaded.
  @protected
  void onIncoming() {}

  // ── Loading ──────────────────────────────────────────────────────────────────
  Future<void> load() async {
    try {
      final page = await fetchPage();
      _messages = _sorted(page);
      _hasMore = page.length >= pageSize;
      _error = null;
      onIncoming();
    } on ApiException catch (e) {
      _error = e.message;
    } finally {
      _isLoading = false;
      _notify();
    }
  }

  Future<void> loadOlder() async {
    if (_isLoadingOlder || !_hasMore || _messages.isEmpty) return;
    _isLoadingOlder = true;
    _notify();
    try {
      final page = await fetchPage(beforeId: _messages.first.id);
      _hasMore = page.length >= pageSize;
      _merge(page);
    } on ApiException catch (e) {
      _error = e.message;
    } finally {
      _isLoadingOlder = false;
      _notify();
    }
  }

  // ── Changing messages ────────────────────────────────────────────────────────
  /// Throws [ApiException] when the backend refuses the message.
  Future<void> send(String content) async {
    final message = await sendText(content);
    _merge([message]);
    _notify();
  }

  Future<void> edit(MessageModel message, String content) async {
    final updated = await editText(message.id, content);
    _merge([updated]);
    _notify();
  }

  Future<void> remove(MessageModel message) async {
    await deleteMessage(message.id);
    removeById(message.id);
    _notify();
  }

  // ── For subclasses ───────────────────────────────────────────────────────────
  @protected
  void addOrReplace(MessageModel message) {
    _merge([message]);
    _notify();
  }

  @protected
  void removeById(int id) {
    _messages = _messages.where((m) => m.id != id).toList();
    _notify();
  }

  @protected
  void markMineRead() {
    bool unread(MessageModel m) => m.senderId == myId && !m.isRead;
    if (!_messages.any(unread)) return;
    _messages = [
      for (final m in _messages) unread(m) ? m.copyWith(isRead: true) : m,
    ];
    _notify();
  }

  void _onRealtimeEvent(RealtimeEvent event) {
    if (event.type == RealtimeEvent.connected) {
      // The socket was down for a while: pick up anything that was missed.
      unawaited(_catchUp());
      return;
    }
    handleEvent(event);
  }

  Future<void> _catchUp() async {
    try {
      _merge(await fetchPage());
      onIncoming();
      _notify();
    } on ApiException {
      // Still offline; the next reconnect tries again.
    }
  }

  void _merge(List<MessageModel> incoming) {
    final byId = {for (final m in _messages) m.id: m};
    for (final m in incoming) {
      byId[m.id] = m;
    }
    _messages = _sorted(byId.values);
  }

  List<MessageModel> _sorted(Iterable<MessageModel> list) =>
      list.toList()..sort((a, b) {
        final byTime = a.createdAt.compareTo(b.createdAt);
        return byTime != 0 ? byTime : a.id.compareTo(b.id);
      });

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _events.cancel();
    super.dispose();
  }
}

/// A one-to-one chat with [partner].
class DirectThreadController extends ChatThreadController {
  DirectThreadController(
    super.realtime, {
    required super.myId,
    required this.partner,
    required MessageService service,
    this.onRead,
  }) : _service = service;

  final UserPublic partner;
  final MessageService _service;

  /// Told when this chat's unread badge should be cleared.
  final VoidCallback? onRead;

  @override
  Future<List<MessageModel>> fetchPage({int? beforeId}) =>
      _service.directMessages(
        partner.id,
        limit: ChatThreadController.pageSize,
        beforeId: beforeId,
      );

  @override
  Future<MessageModel> sendText(String content) =>
      _service.sendDirect(partner.id, content);

  @override
  Future<MessageModel> editText(int id, String content) =>
      _service.editDirect(partner.id, id, content);

  @override
  Future<void> deleteMessage(int id) => _service.deleteDirect(partner.id, id);

  @override
  void onIncoming() {
    // The chat is open, so whatever the partner sent counts as read.
    unawaited(
      _service
          .markRead(partner.id)
          .then((_) => onRead?.call())
          .catchError((Object _) {}),
    );
  }

  @override
  void handleEvent(RealtimeEvent event) {
    switch (event.type) {
      case 'message':
      case 'message_edited':
        final message = MessageModel.fromJson(event.data);
        if (message.senderId != partner.id &&
            message.receiverId != partner.id) {
          return;
        }
        addOrReplace(message);
        if (event.type == 'message') onIncoming();
      case 'message_deleted':
        final id = event.data['id'];
        if (id is int) removeById(id);
      case 'read':
        if (event.data['reader_id'] == partner.id) markMineRead();
    }
  }
}

/// The chat of a server.
class ServerThreadController extends ChatThreadController {
  ServerThreadController(
    super.realtime, {
    required super.myId,
    required this.serverId,
    required MessageService service,
  }) : _service = service;

  final int serverId;
  final MessageService _service;

  @override
  Future<List<MessageModel>> fetchPage({int? beforeId}) =>
      _service.groupMessages(
        serverId,
        limit: ChatThreadController.pageSize,
        beforeId: beforeId,
      );

  @override
  Future<MessageModel> sendText(String content) =>
      _service.sendGroup(serverId, content);

  @override
  Future<MessageModel> editText(int id, String content) =>
      _service.editGroup(serverId, id, content);

  @override
  Future<void> deleteMessage(int id) => _service.deleteGroup(serverId, id);

  @override
  void handleEvent(RealtimeEvent event) {
    switch (event.type) {
      case 'group_message':
      case 'group_message_edited':
        final message = MessageModel.fromJson(event.data);
        if (message.serverId == serverId) addOrReplace(message);
      case 'group_message_deleted':
        final id = event.data['id'];
        if (event.data['server_id'] == serverId && id is int) removeById(id);
    }
  }
}
