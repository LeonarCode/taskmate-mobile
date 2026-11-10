import 'dart:async';
import 'package:flutter/material.dart';
import '../models/message_model.dart';
import '../services/api_client.dart';
import '../services/message_service.dart';
import '../services/realtime_service.dart';
import 'session_bound.dart';

/// The Chats tab: one row per person the user talks to. The backend is the
/// source of truth for the last message and the unread counts, so this simply
/// reloads the list (briefly debounced) whenever a direct-message event arrives.
class ChatProvider extends ChangeNotifier with SessionBound {
  ChatProvider(this._service, RealtimeService realtime) {
    _events = realtime.events.listen(_onEvent);
  }

  final MessageService _service;
  late final StreamSubscription<RealtimeEvent> _events;
  Timer? _debounce;

  List<ConversationModel> _conversations = [];
  bool _isLoading = false;
  String? _error;

  List<ConversationModel> get conversations =>
      List.unmodifiable(_conversations);
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get totalUnread =>
      _conversations.fold(0, (sum, c) => sum + c.unreadCount);

  @override
  void onSessionReset() {
    _debounce?.cancel();
    _conversations = [];
    _isLoading = false;
    _error = null;
  }

  @override
  Future<void> onSessionStart() async {
    _isLoading = true;
    notifyListeners();
    await refresh();
  }

  Future<void> refresh() async {
    final userId = sessionUserId;
    if (userId == null) return;
    try {
      final list = await _service.conversations();
      if (sessionUserId != userId) return;
      _conversations = list;
      _error = null;
    } on ApiException catch (e) {
      if (sessionUserId != userId) return;
      _error = e.message;
    } finally {
      if (sessionUserId == userId) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  /// The user opened a conversation: clear its badge right away.
  void markReadLocally(int partnerId) {
    final index = _conversations.indexWhere((c) => c.partner.id == partnerId);
    if (index == -1 || _conversations[index].unreadCount == 0) return;
    final c = _conversations[index];
    _conversations[index] = ConversationModel(
      partner: c.partner,
      lastMessage: c.lastMessage,
      unreadCount: 0,
    );
    notifyListeners();
  }

  void _onEvent(RealtimeEvent event) {
    if (sessionUserId == null) return;
    switch (event.type) {
      case RealtimeEvent.connected:
      case 'message':
      case 'message_edited':
      case 'message_deleted':
      case 'read':
        _debounce?.cancel();
        _debounce = Timer(const Duration(milliseconds: 300), refresh);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _events.cancel();
    super.dispose();
  }
}
