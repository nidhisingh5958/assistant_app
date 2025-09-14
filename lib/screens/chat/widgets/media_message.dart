import 'package:flutter/material.dart';
import 'package:listen_iq/screens/chat/entities/message_bot.dart';

class MediaMessage extends StatelessWidget {
  const MediaMessage({required this.message, super.key});

  final Message message;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.7,
      ),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: message.backgroundGradient,
          borderRadius: message.getBorderRadius(),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                message.mediaUrl ?? '',
                height: 180,
                width: double.maxFinite,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    height: 180,
                    width: double.maxFinite,
                    color: Colors.blue[200],
                    child: const Center(child: CircularProgressIndicator()),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    height: 180,
                    width: double.maxFinite,
                    color: Colors.blue[200],
                    child: const Center(
                      child: Icon(Icons.error_outline, size: 40),
                    ),
                  );
                },
              ),
            ),
            if (message.text != null) ...[
              const SizedBox(height: 8),
              Text(message.text!, style: TextStyle(color: message.textColor)),
            ],
          ],
        ),
      ),
    );
  }
}
