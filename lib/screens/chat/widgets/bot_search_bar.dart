import 'package:flutter/material.dart';
import 'package:listen_iq/screens/chat/entities/message_bot.dart';
import 'package:listen_iq/screens/chat/answerUser.dart';

class BotSearchBar extends StatefulWidget {
  final Function(Message)? onMessageSent;
  final Function()? onTyping;

  const BotSearchBar({super.key, this.onMessageSent, this.onTyping});

  @override
  State<BotSearchBar> createState() => _BotSearchBarState();
}

class _BotSearchBarState extends State<BotSearchBar> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _isProcessing = false;

  Future<void> _sendMessage() async {
    final query = _controller.text.trim();
    if (query.isEmpty || _isProcessing) return;

    // Send user message first
    final userMessage = Message(
      type: MessageType.text,
      sender: MessageSender.user,
      text: query,
    );
    widget.onMessageSent?.call(userMessage);

    // Clear input and show processing state
    _controller.clear();
    setState(() {
      _isProcessing = true;
    });

    // Notify about typing
    widget.onTyping?.call();

    // Add typing indicator
    final typingMessage = Message(
      type: MessageType.text,
      sender: MessageSender.bot,
      text: "Thinking...",
    );
    widget.onMessageSent?.call(typingMessage);

    try {
      // Use the askQuestion function from answerUser.dart
      final botResponseText = await askQuestion(query);

      final botResponse = Message(
        type: MessageType.text,
        sender: MessageSender.bot,
        text: botResponseText,
      );
      widget.onMessageSent?.call(botResponse);
    } catch (e) {
      // Fallback error message
      final errorMessage = Message(
        type: MessageType.text,
        sender: MessageSender.bot,
        text:
            "I encountered an error while processing your question. Please try again.",
      );
      widget.onMessageSent?.call(errorMessage);
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.transparent,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _controller,
                focusNode: _focusNode,
                enabled: !_isProcessing,
                decoration: InputDecoration(
                  hintText: _isProcessing
                      ? "Processing your question..."
                      : "Ask me about conversations, memories...",
                  hintStyle: TextStyle(fontSize: 14, color: Colors.grey[500]),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  filled: true,
                  fillColor: const Color.fromARGB(255, 72, 71, 71),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  suffixIcon: _buildSendButton(),
                ),
                style: const TextStyle(fontSize: 14),
                minLines: 1,
                maxLines: 4,
                onFieldSubmitted: (_) => _sendMessage(),
                onChanged: (text) {
                  setState(() {}); // Rebuild to update send button state
                },
                cursorColor: const Color.fromARGB(255, 179, 154, 248),
                textInputAction: TextInputAction.send,
                keyboardType: TextInputType.multiline,
                autocorrect: true,
                autofocus: false,
                enableInteractiveSelection: true,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSendButton() {
    if (_isProcessing) {
      return Container(
        margin: const EdgeInsets.all(12),
        width: 20,
        height: 20,
        child: const CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(Colors.grey),
        ),
      );
    }

    final isEnabled = _controller.text.trim().isNotEmpty;

    return Container(
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isEnabled ? Colors.deepPurpleAccent : Colors.grey[300],
        shape: BoxShape.circle,
      ),
      child: IconButton(
        icon: Icon(
          Icons.send_rounded,
          color: isEnabled ? Colors.white : Colors.grey[600],
        ),
        onPressed: isEnabled ? _sendMessage : null,
      ),
    );
  }
}
