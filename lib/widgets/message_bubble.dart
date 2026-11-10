import 'package:flutter/material.dart';
import '../core/format.dart';
import '../core/theme.dart';
import '../models/message_model.dart';

class MessageBubble extends StatelessWidget {
  final MessageModel message;
  final bool isMe;
  final String senderName;
  final Widget avatar;

  /// Show the sender's first name above the bubble (server chat).
  final bool showSenderName;

  /// Show "Seen" under the bubble (last message I sent that was read).
  final bool showSeen;

  /// Edit / delete menu, only for messages I sent.
  final VoidCallback? onLongPress;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    required this.senderName,
    required this.avatar,
    this.showSenderName = true,
    this.showSeen = false,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (message.type == MessageType.systemMessage) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isDark ? AppColors.dark700 : AppColors.gray100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              message.content,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isDark ? AppColors.gray400 : AppColors.gray500,
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: isMe
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        children: [
          if (!isMe) ...[avatar, const SizedBox(width: 8)],
          Flexible(
            child: Column(
              crossAxisAlignment: isMe
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                if (!isMe && showSenderName)
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 3),
                    child: Text(
                      senderName.split(' ').first,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.purple600,
                      ),
                    ),
                  ),
                GestureDetector(
                  onLongPress: onLongPress,
                  child: Container(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.72,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      gradient: isMe ? AppColors.primaryGradient : null,
                      color: isMe
                          ? null
                          : (isDark ? AppColors.dark700 : AppColors.gray100),
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(18),
                        topRight: const Radius.circular(18),
                        bottomLeft: Radius.circular(isMe ? 18 : 4),
                        bottomRight: Radius.circular(isMe ? 4 : 18),
                      ),
                      boxShadow: isMe
                          ? [
                              BoxShadow(
                                color: AppColors.purple600.withAlpha(40),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                    child: _content(isDark),
                  ),
                ),
                const SizedBox(height: 2),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    [
                      clockLabel(message.createdAt),
                      if (message.isEdited) 'edited',
                      if (showSeen) 'Seen',
                    ].join(' · '),
                    style: TextStyle(
                      fontSize: 10,
                      color: isDark ? AppColors.gray500 : AppColors.gray400,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (isMe) ...[const SizedBox(width: 8), avatar],
        ],
      ),
    );
  }

  Widget _content(bool isDark) {
    final textColor = isMe
        ? Colors.white
        : (isDark ? Colors.white : AppColors.gray900);
    final text = Text(
      message.content,
      style: TextStyle(
        fontSize: 14,
        color: textColor,
        height: 1.4,
        fontWeight: FontWeight.w500,
      ),
    );

    switch (message.type) {
      case MessageType.image:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (message.imageUrl != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(
                  message.imageUrl!,
                  errorBuilder: (_, _, _) => Text(
                    '📷 Photo unavailable',
                    style: TextStyle(color: textColor),
                  ),
                ),
              ),
            if (message.content.isNotEmpty) ...[
              const SizedBox(height: 6),
              text,
            ],
          ],
        );
      case MessageType.taskRef:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.push_pin_rounded, size: 16, color: textColor),
            const SizedBox(width: 6),
            Flexible(
              child: message.content.isEmpty
                  ? Text('Shared a task', style: TextStyle(color: textColor))
                  : text,
            ),
          ],
        );
      case MessageType.text:
      case MessageType.systemMessage:
        return text;
    }
  }
}
