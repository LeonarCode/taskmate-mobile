import 'dart:async';
import 'package:flutter/material.dart';
import '../models/notification_model.dart';
import '../services/alert_service.dart';
import '../services/api_client.dart';
import '../services/realtime_service.dart';
import 'session_bound.dart';

/// The Alerts tab. New notifications arrive over the WebSocket, and read /
/// delete actions are echoed to every device of the user, so the badge stays
/// the same everywhere.
class AlertProvider extends ChangeNotifier with SessionBound {
  AlertProvider(this._service, RealtimeService realtime) {
    _events = realtime.events.listen(_onEvent);
  }

  final AlertService _service;
  late final StreamSubscription<RealtimeEvent> _events;

  List<NotificationModel> _items = [];
  int _unreadCount = 0;
  bool _isLoading = false;
  String? _error;

  List<NotificationModel> get items => List.unmodifiable(_items);
  int get unreadCount => _unreadCount;
  bool get isLoading => _isLoading;
  String? get error => _error;

  @override
  void onSessionReset() {
    _items = [];
    _unreadCount = 0;
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
      final results = await Future.wait([
        _service.list(),
        _service.unreadCount(),
      ]);
      if (sessionUserId != userId) return;
      _items = results[0] as List<NotificationModel>;
      _unreadCount = results[1] as int;
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

  // ── Actions (optimistic; the backend echoes them to the other devices) ───────
  Future<void> markRead(int id) async {
    if (!_applyRead(id)) return;
    notifyListeners();
    await _quietly(() => _service.markRead(id));
  }

  Future<void> markAllRead() async {
    if (_unreadCount == 0 && _items.every((n) => n.isRead)) return;
    _applyReadAll();
    notifyListeners();
    await _quietly(_service.markAllRead);
  }

  Future<void> delete(int id) async {
    _applyDelete(id);
    notifyListeners();
    await _quietly(() => _service.delete(id));
  }

  Future<void> clearAll() async {
    _items = [];
    _unreadCount = 0;
    notifyListeners();
    await _quietly(_service.clearAll);
  }

  Future<void> _quietly(Future<void> Function() action) async {
    try {
      await action();
    } on ApiException {
      // Put the list back in line with the backend.
      await refresh();
    }
  }

  // ── Realtime ─────────────────────────────────────────────────────────────────
  void _onEvent(RealtimeEvent event) {
    if (sessionUserId == null) return;
    switch (event.type) {
      case RealtimeEvent.connected:
        refresh();
        return;
      case 'notification':
        final item = NotificationModel.fromJson(event.data);
        if (_items.any((n) => n.id == item.id)) return;
        _items = [item, ..._items];
        if (!item.isRead) _unreadCount++;
      case 'notification_read':
        _applyRead(event.data['id'] as int?);
      case 'notifications_read_all':
        _applyReadAll();
      case 'notification_deleted':
        _applyDelete(event.data['id'] as int?);
      case 'notifications_cleared':
        _items = [];
        _unreadCount = 0;
      default:
        return;
    }
    notifyListeners();
  }

  /// Returns true if something changed.
  bool _applyRead(int? id) {
    final index = _items.indexWhere((n) => n.id == id);
    if (index == -1 || _items[index].isRead) return false;
    _items[index] = _items[index].copyWith(isRead: true);
    if (_unreadCount > 0) _unreadCount--;
    return true;
  }

  void _applyReadAll() {
    _items = [for (final n in _items) n.copyWith(isRead: true)];
    _unreadCount = 0;
  }

  void _applyDelete(int? id) {
    final index = _items.indexWhere((n) => n.id == id);
    if (index == -1) return;
    if (!_items[index].isRead && _unreadCount > 0) _unreadCount--;
    _items.removeAt(index);
  }

  @override
  void dispose() {
    _events.cancel();
    super.dispose();
  }
}
