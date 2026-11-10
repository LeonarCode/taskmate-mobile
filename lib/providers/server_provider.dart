import 'dart:async';
import 'package:flutter/material.dart';
import '../models/server_model.dart';
import '../services/api_client.dart';
import '../services/server_service.dart';
import 'session_bound.dart';

/// The Servers tab: servers I'm in ("My Servers") and the ones I could join
/// ("Discover").
class ServerProvider extends ChangeNotifier with SessionBound {
  ServerProvider(this._service);

  final ServerService _service;
  Timer? _searchDebounce;

  List<ServerModel> _joined = [];
  List<ServerModel> _discover = [];
  String _discoverQuery = '';
  bool _isLoading = false;
  bool _isDiscoverLoading = false;
  String? _error;

  List<ServerModel> get joined => List.unmodifiable(_joined);
  List<ServerModel> get discover => List.unmodifiable(_discover);
  bool get isLoading => _isLoading;
  bool get isDiscoverLoading => _isDiscoverLoading;
  String? get error => _error;

  @override
  void onSessionReset() {
    _searchDebounce?.cancel();
    _joined = [];
    _discover = [];
    _discoverQuery = '';
    _isLoading = false;
    _isDiscoverLoading = false;
    _error = null;
  }

  @override
  Future<void> onSessionStart() async {
    _isLoading = true;
    _isDiscoverLoading = true;
    notifyListeners();
    await refresh();
  }

  Future<void> refresh() => Future.wait([loadJoined(), loadDiscover()]);

  Future<void> loadJoined() async {
    final userId = sessionUserId;
    if (userId == null) return;
    try {
      final list = await _service.joined();
      if (sessionUserId != userId) return;
      _joined = list;
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

  Future<void> loadDiscover() async {
    final userId = sessionUserId;
    if (userId == null) return;
    final query = _discoverQuery;
    try {
      final list = await _service.discover(search: query);
      if (sessionUserId != userId || query != _discoverQuery) return;
      _discover = list;
      _error = null;
    } on ApiException catch (e) {
      if (sessionUserId != userId) return;
      _error = e.message;
    } finally {
      if (sessionUserId == userId && query == _discoverQuery) {
        _isDiscoverLoading = false;
        notifyListeners();
      }
    }
  }

  /// Discover is searched on the backend; typing is debounced.
  void searchDiscover(String query) {
    final trimmed = query.trim();
    if (trimmed == _discoverQuery) return;
    _discoverQuery = trimmed;
    _isDiscoverLoading = true;
    notifyListeners();
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), loadDiscover);
  }

  /// Throws [ApiException] when the backend refuses.
  Future<ServerModel> join(int serverId) async {
    final server = await _service.join(serverId);
    await refresh();
    return server;
  }

  Future<ServerModel> create({
    required String name,
    required String description,
    required int iconColorValue,
    String? iconEmoji,
  }) async {
    final server = await _service.create(
      name: name,
      description: description,
      iconColorValue: iconColorValue,
      iconEmoji: iconEmoji,
    );
    await refresh();
    return server;
  }

  Future<void> leave(int serverId) async {
    await _service.leave(serverId);
    await refresh();
  }

  Future<void> deleteServer(int serverId) async {
    await _service.delete(serverId);
    await refresh();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    super.dispose();
  }
}
