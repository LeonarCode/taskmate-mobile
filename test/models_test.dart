import 'package:flutter_test/flutter_test.dart';
import 'package:taskmate_ui/core/constants.dart';
import 'package:taskmate_ui/core/format.dart';
import 'package:taskmate_ui/models/message_model.dart';
import 'package:taskmate_ui/models/notification_model.dart';
import 'package:taskmate_ui/models/rating_model.dart';
import 'package:taskmate_ui/models/server_model.dart';
import 'package:taskmate_ui/models/task_model.dart';
import 'package:taskmate_ui/models/user_model.dart';

// Payloads follow the backend's pydantic response schemas.
void main() {
  group('time helpers', () {
    test('parses timestamps with a zone', () {
      expect(
        parseServerTime('2026-10-10T09:00:00+00:00').toUtc(),
        DateTime.utc(2026, 10, 10, 9),
      );
      expect(
        parseServerTime('2026-10-10T17:00:00+08:00').toUtc(),
        DateTime.utc(2026, 10, 10, 9),
      );
      expect(
        parseServerTime('2026-10-10T09:00:00.123456Z').toUtc(),
        DateTime.utc(2026, 10, 10, 9, 0, 0, 123, 456),
      );
    });

    test('treats a timestamp without a zone as UTC', () {
      expect(
        parseServerTime('2026-10-10T09:00:00').toUtc(),
        DateTime.utc(2026, 10, 10, 9),
      );
    });

    test('always sends UTC with a zone marker', () {
      final sent = toServerTime(DateTime(2026, 10, 10, 17));
      expect(sent.endsWith('Z'), isTrue);
      expect(DateTime.parse(sent), DateTime(2026, 10, 10, 17).toUtc());
    });

    test('initialOf handles empty and emoji names', () {
      expect(initialOf(''), '?');
      expect(initialOf('  leonard'), 'L');
      expect(initialOf('😀 Smile'), '😀');
    });
  });

  group('users', () {
    test('UserResponse', () {
      final user = UserModel.fromJson({
        'id': 7,
        'username': 'leo',
        'email': 'leo@example.com',
        'fullname': 'Leonard Balaba',
        'age': 21,
        'organization': null,
        'user_type': 'employee',
        'photo_url': 'data:image/jpeg;base64,AAAA',
        'average_rating': 4.5,
        'rating_count': 2,
        'created_at': '2026-10-01T00:00:00Z',
      });
      expect(user.id, 7);
      expect(user.fullName, 'Leonard Balaba');
      expect(user.userType, UserType.employee);
      expect(user.organization, isNull);
      expect(user.averageRating, 4.5);
      expect(user.asPublic.hasPhoto, isTrue);
      // The offline cache round-trips.
      final again = UserModel.fromJson(user.toJson());
      expect(again.email, user.email);
      expect(again.createdAt, user.createdAt);
    });

    test('an integer average rating still parses', () {
      final user = UserModel.fromJson({
        'id': 1,
        'username': 'a',
        'email': 'a@b.co',
        'fullname': 'A',
        'age': 1,
        'user_type': 'student',
        'average_rating': 0,
        'rating_count': 0,
        'created_at': '2026-10-01T00:00:00Z',
      });
      expect(user.averageRating, 0.0);
      expect(user.userType, UserType.student);
    });

    test('UserPublic has no photo itself, only a flag', () {
      final user = UserPublic.fromJson({
        'id': 3,
        'username': 'sam',
        'fullname': 'Sam',
        'has_photo': true,
        'average_rating': 3.0,
        'rating_count': 1,
      });
      expect(user.hasPhoto, isTrue);
      expect(user.fullName, 'Sam');
    });
  });

  group('tasks', () {
    final personal = {
      'id': 11,
      'uid': 7,
      'client_id': '3f2b8c1e-0000-4000-8000-000000000001',
      'title': 'Finish report',
      'description': '',
      'priority': 'high',
      'deadline': '2026-10-12T09:00:00Z',
      'has_alarm': true,
      'is_complete': true,
      'completed_at': '2026-10-11T08:00:00Z',
      'created_at': '2026-10-10T00:00:00Z',
      'updated_at': '2026-10-10T00:00:00Z',
    };

    test('a personal task is addressed by its client_id', () {
      final task = TaskModel.fromPersonalApi(personal, '7')!;
      expect(task.id, '3f2b8c1e-0000-4000-8000-000000000001');
      expect(task.remoteId, 11);
      expect(task.priority, TaskPriority.high);
      expect(task.isCompleted, isTrue);
      expect(task.isSynced, isTrue);
      expect(task.isGroup, isFalse);
    });

    test('a personal task without a client_id is skipped', () {
      expect(
        TaskModel.fromPersonalApi({...personal, 'client_id': null}, '7'),
        isNull,
      );
    });

    test('upsert body uses the backend field names', () {
      final body = TaskModel.fromPersonalApi(personal, '7')!.toUpsertBody();
      expect(body['priority'], 'high');
      expect(body['is_complete'], true);
      expect(body['has_alarm'], true);
      expect(body['deadline'], '2026-10-12T09:00:00.000Z');
      expect(body['completed_at'], '2026-10-11T08:00:00.000Z');
      expect(body.containsKey('client_id'), isFalse);
    });

    test('a group task keeps its server', () {
      final task = TaskModel.fromGroupApi({
        'id': 5,
        'server_id': 2,
        'title': 'Slides',
        'description': 'Intro deck',
        'priority': 'low',
        'deadline': '2026-10-12T09:00:00Z',
        'has_alarm': false,
        'is_complete': false,
        'completed_at': null,
        'created_at': '2026-10-10T00:00:00Z',
        'updated_at': '2026-10-10T00:00:00Z',
      });
      expect(task.id, 'g5');
      expect(task.remoteId, 5);
      expect(task.serverId, 2);
      expect(task.isGroup, isTrue);
      expect(task.hasAlarm, isFalse);
    });

    test('the local cache round-trips', () {
      final task = TaskModel.fromPersonalApi(
        personal,
        '7',
      )!.copyWith(isSynced: false, isDeleted: true);
      final again = TaskModel.fromLocal(task.toLocal());
      expect(again.id, task.id);
      expect(again.isDeleted, isTrue);
      expect(again.isSynced, isFalse);
      expect(again.priority, TaskPriority.high);
      expect(again.completedAt, task.completedAt);
    });
  });

  group('servers', () {
    test('ServerResponse parses the icon color text', () {
      final server = ServerModel.fromJson({
        'name': 'Study Group',
        'description': 'CS 101',
        'icon_color': '0xFFEC4899',
        'icon_emoji': '📚',
        'id': 2,
        'owner_id': 7,
        'member_count': 4,
        'created_at': '2026-10-01T00:00:00Z',
      });
      expect(server.iconColorValue, 0xFFEC4899);
      expect(server.iconEmoji, '📚');
      expect(server.memberCount, 4);
    });

    test('colors are sent in the exact form the backend accepts', () {
      for (final c in kServerColors) {
        final text = ServerModel.colorToApi(c);
        expect(
          RegExp(r'^0xFF[0-9A-F]{6}$').hasMatch(text),
          isTrue,
          reason: text,
        );
        expect(int.parse(text), c);
      }
      expect(ServerModel.colorToApi(0xFF7C3AED), '0xFF7C3AED');
    });

    test('MemberResponse', () {
      final member = MemberModel.fromJson({
        'user': {
          'id': 3,
          'username': 'sam',
          'fullname': 'Sam',
          'has_photo': false,
          'average_rating': 0.0,
          'rating_count': 0,
        },
        'joined_at': '2026-10-02T00:00:00Z',
        'is_owner': true,
      });
      expect(member.isOwner, isTrue);
      expect(member.user.username, 'sam');
    });
  });

  group('messages', () {
    test('a direct message', () {
      final m = MessageModel.fromJson({
        'content': 'hi',
        'task_ref_id': null,
        'image_url': null,
        'message_type': 'text',
        'id': 40,
        'sender_id': 7,
        'receiver_id': 3,
        'is_read': true,
        'edited_at': '2026-10-10T10:05:00Z',
        'created_at': '2026-10-10T10:00:00Z',
      });
      expect(m.receiverId, 3);
      expect(m.sender, isNull);
      expect(m.isRead, isTrue);
      expect(m.isEdited, isTrue);
      expect(m.type, MessageType.text);
    });

    test('a group message carries its sender and server', () {
      final m = MessageModel.fromJson({
        'content': '',
        'task_ref_id': 5,
        'image_url': null,
        'message_type': 'task_ref',
        'id': 41,
        'sender_id': 3,
        'sender': {
          'id': 3,
          'username': 'sam',
          'fullname': 'Sam',
          'has_photo': true,
          'average_rating': 0.0,
          'rating_count': 0,
        },
        'server_id': 2,
        'edited_at': null,
        'created_at': '2026-10-10T10:00:00Z',
      });
      expect(m.serverId, 2);
      expect(m.sender!.fullName, 'Sam');
      expect(m.type, MessageType.taskRef);
      expect(m.preview, '📌 Task');
    });

    test('a conversation row', () {
      final c = ConversationModel.fromJson({
        'partner': {
          'id': 3,
          'username': 'sam',
          'fullname': 'Sam',
          'has_photo': false,
          'average_rating': 0.0,
          'rating_count': 0,
        },
        'last_message': {
          'content': 'see you',
          'message_type': 'text',
          'id': 50,
          'sender_id': 3,
          'receiver_id': 7,
          'is_read': false,
          'created_at': '2026-10-10T10:00:00Z',
        },
        'unread_count': 2,
      });
      expect(c.unreadCount, 2);
      expect(c.lastMessage.preview, 'see you');
    });

    test('unknown message types fall back to text', () {
      expect(MessageType.fromApi('something_new'), MessageType.text);
    });
  });

  group('notifications and ratings', () {
    test('a notification with a reference', () {
      final n = NotificationModel.fromJson({
        'id': 9,
        'content': 'Sam joined Study Group',
        'notification_type': 'server_activity',
        'is_read': false,
        'created_at': '2026-10-10T10:00:00Z',
        'reference': {'task_id': null, 'server_id': 2, 'dm_id': null},
      });
      expect(n.type, NotifType.serverActivity);
      expect(n.serverId, 2);
      expect(n.taskId, isNull);
      expect(n.copyWith(isRead: true).isRead, isTrue);
    });

    test('a notification without a reference', () {
      final n = NotificationModel.fromJson({
        'id': 10,
        'content': 'Task due',
        'notification_type': 'task_deadline',
        'is_read': true,
        'created_at': '2026-10-10T10:00:00Z',
        'reference': null,
      });
      expect(n.type, NotifType.taskDeadline);
      expect(n.serverId, isNull);
    });

    test('a rating', () {
      const user = {
        'id': 3,
        'username': 'sam',
        'fullname': 'Sam',
        'has_photo': false,
        'average_rating': 4.5,
        'rating_count': 1,
      };
      final r = RatingModel.fromJson({
        'id': 1,
        'score': 4.5,
        'comment': null,
        'created_at': '2026-10-10T10:00:00Z',
        'server': {'id': 2, 'name': 'Study Group'},
        'rater': user,
        'rated': {...user, 'id': 7},
      });
      expect(r.score, 4.5);
      expect(r.comment, isNull);
      expect(r.serverName, 'Study Group');
      expect(r.rated.id, 7);
    });
  });
}
