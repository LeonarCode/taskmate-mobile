import '../models/rating_model.dart';
import '../models/server_model.dart';
import 'api_client.dart';

/// Servers (`/server`) and ratings (`/ratings`).
class ServerService {
  ServerService(this._api);

  final ApiClient _api;

  List<T> _list<T>(dynamic json, T Function(Map<String, dynamic>) parse) =>
      (json as List).map((e) => parse(e as Map<String, dynamic>)).toList();

  // ── Servers ─────────────────────────────────────────────────────────────────
  /// Servers I belong to (including my own).
  Future<List<ServerModel>> joined() async =>
      _list(await _api.get('/server'), ServerModel.fromJson);

  /// Servers I haven't joined, most members first.
  Future<List<ServerModel>> discover({String? search}) async {
    final trimmed = search?.trim();
    return _list(
      await _api.get(
        '/server/discover',
        query: {
          'search': (trimmed == null || trimmed.isEmpty) ? null : trimmed,
          'limit': 100,
        },
      ),
      ServerModel.fromJson,
    );
  }

  Future<ServerModel> create({
    required String name,
    required String description,
    required int iconColorValue,
    String? iconEmoji,
  }) async {
    final json = await _api.post(
      '/server',
      body: {
        'name': name,
        'description': description,
        'icon_color': ServerModel.colorToApi(iconColorValue),
        'icon_emoji': iconEmoji,
      },
    );
    return ServerModel.fromJson(json as Map<String, dynamic>);
  }

  Future<ServerModel> get(int id) async => ServerModel.fromJson(
    await _api.get('/server/$id') as Map<String, dynamic>,
  );

  Future<ServerModel> join(int id) async => ServerModel.fromJson(
    await _api.post('/server/$id/join') as Map<String, dynamic>,
  );

  /// Members only; the owner has to delete the server instead.
  Future<void> leave(int id) => _api.post('/server/$id/leave');

  /// Owner only. Also removes the server's members, tasks, messages and ratings.
  Future<void> delete(int id) => _api.delete('/server/$id');

  Future<List<MemberModel>> members(int id) async =>
      _list(await _api.get('/server/$id/members'), MemberModel.fromJson);

  // ── Ratings ─────────────────────────────────────────────────────────────────
  /// Ratings I gave; pass [serverId] to get the ones for one server.
  Future<List<RatingModel>> given({int? serverId}) async => _list(
    await _api.get(
      '/ratings/given',
      query: {'server_id': serverId, 'limit': 100},
    ),
    RatingModel.fromJson,
  );

  /// Ratings other people gave me, newest first.
  Future<List<RatingModel>> received({int limit = 50}) async => _list(
    await _api.get('/ratings/received', query: {'limit': limit}),
    RatingModel.fromJson,
  );

  /// Creates the rating, or replaces the one I already gave this user here.
  Future<RatingModel> rate({
    required int serverId,
    required int ratedId,
    required double score,
    String? comment,
  }) async {
    final json = await _api.put(
      '/ratings/$serverId/$ratedId',
      body: {'score': score, 'comment': comment},
    );
    return RatingModel.fromJson(json as Map<String, dynamic>);
  }

  Future<void> removeRating({required int serverId, required int ratedId}) =>
      _api.delete('/ratings/$serverId/$ratedId');
}
