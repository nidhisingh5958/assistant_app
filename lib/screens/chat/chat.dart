import 'package:flutter/material.dart';
import 'package:listen_iq/screens/chat/entities/message_bot.dart';
import 'package:listen_iq/screens/chat/entities/message_group.dart';
import 'package:listen_iq/screens/chat/widgets/bot_search_bar.dart';
import 'package:listen_iq/screens/chat/widgets/chat_message_widget.dart';
import 'package:listen_iq/screens/components/appbar.dart';

class ChatScreen extends StatefulWidget {
  final String? initialMessage;

  const ChatScreen({super.key, this.initialMessage});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ScrollController _scrollController = ScrollController();
  List<Message> messages = [];
  List<MessageGroup> messageGroups = [];

  @override
  void initState() {
    super.initState();

    // If there's an initial message, add it and process it
    if (widget.initialMessage != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final initialMessage = Message(
          type: MessageType.text,
          sender: MessageSender.user,
          text: widget.initialMessage!,
        );
        _handleMessageSent(initialMessage);
      });
    }
  }

  void _handleMessageSent(Message message) {
    setState(() {
      // Handle typing indicator replacement
      if (message.sender == MessageSender.bot && messages.isNotEmpty) {
        // Replace the last bot message if it was a typing indicator
        final lastMessage = messages.last;
        if (lastMessage.sender == MessageSender.bot &&
            (lastMessage.text == "Thinking..." ||
                lastMessage.text?.contains("...") == true)) {
          messages.removeLast();
        }
      }

      messages.add(message);
      _groupMessages();

      // Auto-scroll to bottom
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    });
  }

  void _handleTyping() {
    // Optional: Add typing indicator logic here
  }

  void _groupMessages() {
    List<MessageGroup> groups = [];
    List<Message> currentGroup = [];
    MessageSender? currentSender;

    for (var message in messages) {
      if (currentSender != message.sender && currentGroup.isNotEmpty) {
        groups.add(
          MessageGroup(
            messages: List.from(currentGroup),
            sender: currentSender!,
          ),
        );
        currentGroup.clear();
      }
      currentGroup.add(message);
      currentSender = message.sender;
    }

    if (currentGroup.isNotEmpty) {
      groups.add(
        MessageGroup(messages: List.from(currentGroup), sender: currentSender!),
      );
    }

    messageGroups = groups;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppHeader(
        title: "ListenIQ",
        chatTitle: "Health Assistant",
        isInChat: true,
        onBackPressed: () => Navigator.pop(context),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: messages.isEmpty
                  ? _buildEmptyState()
                  : ListView.separated(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 20,
                      ),
                      itemBuilder: (context, index) =>
                          ChatMessageWidget(group: messageGroups[index]),
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 24),
                      itemCount: messageGroups.length,
                    ),
            ),
            BotSearchBar(
              onMessageSent: _handleMessageSent,
              onTyping: _handleTyping,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            "Start a conversation",
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 8),
          Text(
            "Ask me anything about health",
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
}
