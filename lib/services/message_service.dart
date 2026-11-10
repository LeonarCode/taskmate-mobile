import '../models/message_model.dart';
import 'api_client.dart';

/// Direct messages (`/messages`) and server chat (`/server/messages`).
class MessageService {
  MessageService(this._api);

  final ApiClient _api;

  List<MessageModel> _messages(dynamic json) => (json as List)
      .map((e) => MessageModel.fromJson(e as Map<String, dynamic>))
      .toList();

  // ── Direct messages ─────────────────────────────────────────────────────────
  /// Chats tab: one row per person I talk to.
  Future<List<ConversationModel>> conversations() async {
    final json = await _api.get('/messages');
    return (json as List)
        .map((e) => ConversationModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Latest [limit] messages of a conversation. Pass the id of the oldest
  /// message you hold as [beforeId] to get older ones.
  Future<List<MessageModel>> directMessages(
    int partnerId, {
    int limit = 50,
    int? beforeId,
  }) async => _messages(
    await _api.get(
      '/messages/$partnerId',
      query: {'limit': limit, 'before_id': beforeId},
    ),
  );

  Future<MessageModel> sendDirect(int partnerId, String content) async =>
      MessageModel.fromJson(
        await _api.post('/messages/$partnerId', body: {'content': content})
            as Map<String, dynamic>,
      );

  Future<MessageModel> editDirect(
    int partnerId,
    int messageId,
    String content,
  ) async => MessageModel.fromJson(
    await _api.patch(
          '/messages/$partnerId/$messageId',
          body: {'content': content},
        )
        as Map<String, dynamic>,
  );

  Future<void> deleteDirect(int partnerId, int messageId) =>
      _api.delete('/messages/$partnerId/$messageId');

  /// Marks everything from [partnerId] as read (and tells them).
  Future<void> markRead(int partnerId) =>
      _api.post('/messages/$partnerId/read');

  // ── Server chat ─────────────────────────────────────────────────────────────
  Future<List<MessageModel>> groupMessages(
    int serverId, {
    int limit = 50,
    int? beforeId,
  }) async => _messages(
    await _api.get(
      '/server/messages/$serverId',
      query: {'limit': limit, 'before_id': beforeId},
    ),
  );

  Future<MessageModel> sendGroup(int serverId, String content) async =>
      MessageModel.fromJson(
        await _api.post(
              '/server/messages/$serverId',
              body: {'content': content},
            )
            as Map<String, dynamic>,
      );

  Future<MessageModel> editGroup(
    int serverId,
    int messageId,
    String content,
  ) async => MessageModel.fromJson(
    await _api.patch(
          '/server/messages/$serverId/$messageId',
          body: {'content': content},
        )
        as Map<String, dynamic>,
  );

  Future<void> deleteGroup(int serverId, int messageId) =>
      _api.delete('/server/messages/$serverId/$messageId');
}
