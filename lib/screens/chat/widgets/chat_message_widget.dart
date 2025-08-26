import 'package:flutter/material.dart';
import 'package:listen_iq/screens/chat/entities/message_bot.dart';
import 'package:listen_iq/screens/chat/entities/message_group.dart';
import 'package:listen_iq/screens/components/colors.dart';

class ChatMessageWidget extends StatelessWidget {
  final MessageGroup group;

  const ChatMessageWidget({super.key, required this.group});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: group.sender == MessageSender.bot
          ? Alignment.centerLeft
          : Alignment.centerRight,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        child: Column(
          crossAxisAlignment: group.sender == MessageSender.bot
              ? CrossAxisAlignment.start
              : CrossAxisAlignment.end,
          children: [
            if (group.sender == MessageSender.bot) ...[
              Padding(
                padding: const EdgeInsets.only(left: 12, bottom: 4),
                child: Row(
                  // heading above message box (bot side)
                  children: [
                    // CircleAvatar(
                    //   radius: 12,
                    //   backgroundColor: Colors.blue[100],
                    //   child: Icon(Icons.health_and_safety,
                    //       size: 16, color: Colors.blue[900]),
                    // ),
                    // SizedBox(width: 8),
                    Text(
                      'ListenIQ',
                      style: TextStyle(
                        fontSize: 12,
                        color: black.withValues(alpha: .8),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            ...List.generate(
              group.messages.length,
              (index) => Padding(
                padding: EdgeInsets.only(
                  bottom: index == group.messages.length - 1 ? 0 : 2,
                ),
                child: _buildMessageContent(
                  group.messages[index],
                  isFirst: index == 0,
                  isLast: index == group.messages.length - 1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageContent(
    Message message, {
    required bool isFirst,
    required bool isLast,
  }) {
    return Container(
      padding: EdgeInsets.all(message.type == MessageType.text ? 12 : 8),
      decoration: BoxDecoration(
        gradient: message.backgroundGradient,
        borderRadius: message.getBorderRadius(isFirst: isFirst, isLast: isLast),
        // chat bubble shadow
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .05),
            blurRadius: 5,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: message.type == MessageType.text
          ? Text(
              message.text!,
              style: TextStyle(
                color: message.textColor,
                fontSize: 14,
                height: 1.4,
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    message.mediaUrl!,
                    height: 180,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        height: 180,
                        width: double.infinity,
                        color: Colors.blue[50],
                        child: Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.blue[200]!,
                            ),
                          ),
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        height: 180,
                        width: double.infinity,
                        color: Colors.blue[50],
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.error_outline,
                              size: 32,
                              color: Colors.blue[200],
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Could not load image',
                              style: TextStyle(
                                color: Colors.blue[200],
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                if (message.text != null) ...[
                  SizedBox(height: 8),
                  Text(
                    message.text!,
                    style: TextStyle(
                      color: message.textColor,
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}
