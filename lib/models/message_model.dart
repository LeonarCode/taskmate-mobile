import '../core/format.dart';
import 'user_model.dart';

enum MessageType {
  text('text'),
  image('image'),
  taskRef('task_ref'),
  systemMessage('system_message');

  const MessageType(this.apiValue);
  final String apiValue;

  static MessageType fromApi(String? value) => MessageType.values.firstWhere(
    (t) => t.apiValue == value,
    orElse: () => MessageType.text,
  );
}

/// A direct message or a server (group) message. Group messages carry the
/// [sender] and [serverId]; direct messages carry [receiverId] and [isRead].
class MessageModel {
  final int id;
  final int senderId;
  final int? receiverId;
  final int? serverId;
  final UserPublic? sender;
  final String content;
  final MessageType type;
  final String? imageUrl;
  final int? taskRefId;
  final bool isRead;
  final DateTime? editedAt;
  final DateTime createdAt;

  const MessageModel({
    required this.id,
    required this.senderId,
    this.receiverId,
    this.serverId,
    this.sender,
    this.content = '',
    this.type = MessageType.text,
    this.imageUrl,
    this.taskRefId,
    this.isRead = false,
    this.editedAt,
    required this.createdAt,
  });

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    final sender = json['sender'];
    return MessageModel(
      id: json['id'] as int,
      senderId: json['sender_id'] as int,
      receiverId: json['receiver_id'] as int?,
      serverId: json['server_id'] as int?,
      sender: sender is Map<String, dynamic>
          ? UserPublic.fromJson(sender)
          : null,
      content: json['content'] as String? ?? '',
      type: MessageType.fromApi(json['message_type'] as String?),
      imageUrl: json['image_url'] as String?,
      taskRefId: json['task_ref_id'] as int?,
      isRead: json['is_read'] as bool? ?? false,
      editedAt: parseServerTimeOrNull(json['edited_at']),
      createdAt: parseServerTimeOrNull(json['created_at']) ?? DateTime.now(),
    );
  }

  bool get isEdited => editedAt != null;

  /// What to show in a conversation list preview.
  String get preview {
    switch (type) {
      case MessageType.image:
        return '📷 Photo';
      case MessageType.taskRef:
        return '📌 Task';
      case MessageType.text:
      case MessageType.systemMessage:
        return content;
    }
  }

  MessageModel copyWith({bool? isRead}) => MessageModel(
    id: id,
    senderId: senderId,
    receiverId: receiverId,
    serverId: serverId,
    sender: sender,
    content: content,
    type: type,
    imageUrl: imageUrl,
    taskRefId: taskRefId,
    isRead: isRead ?? this.isRead,
    editedAt: editedAt,
    createdAt: createdAt,
  );
}

/// One row of the Chats tab (`GET /messages`).
class ConversationModel {
  final UserPublic partner;
  final MessageModel lastMessage;
  final int unreadCount;

  const ConversationModel({
    required this.partner,
    required this.lastMessage,
    this.unreadCount = 0,
  });

  factory ConversationModel.fromJson(Map<String, dynamic> json) {
    return ConversationModel(
      partner: UserPublic.fromJson(json['partner'] as Map<String, dynamic>),
      lastMessage: MessageModel.fromJson(
        json['last_message'] as Map<String, dynamic>,
      ),
      unreadCount: json['unread_count'] as int? ?? 0,
    );
  }
}
