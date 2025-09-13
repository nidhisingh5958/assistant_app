import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:listen_iq/screens/chat/widgets/bot_search_bar.dart';
import 'package:listen_iq/screens/components/appbar.dart';
import 'package:listen_iq/screens/components/sidemenu.dart';
import 'package:listen_iq/screens/chat/entities/message_bot.dart';
import 'package:listen_iq/screens/chat/entities/message_group.dart';
import 'package:listen_iq/screens/chat/widgets/chat_message_widget.dart';
import '../../services/router_constants.dart';

class ChatHome extends StatefulWidget {
  const ChatHome({super.key});

  @override
  State<ChatHome> createState() => _ChatHomeState();
}

class _ChatHomeState extends State<ChatHome> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final ScrollController _scrollController = ScrollController();

  List<Message> messages = [];
  List<MessageGroup> messageGroups = [];
  bool _showWelcome = true;

  void _handleMessageSent(Message message) {
    setState(() {
      // If this is the first message, hide welcome screen
      if (_showWelcome) {
        _showWelcome = false;
      }

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
    // This is called when the bot starts "typing"
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
      key: _scaffoldKey,
      drawer: const SideMenu(),
      appBar: AppHeader(
        title: "ListenIQ",
        chatTitle: _showWelcome ? null : "Health Assistant",
        isInChat: !_showWelcome,
        onMenuPressed: () {
          final scaffoldState = _scaffoldKey.currentState;
          if (scaffoldState?.hasDrawer == true) {
            scaffoldState!.openDrawer();
          }
        },
        onBackPressed: _showWelcome
            ? null
            : () {
                setState(() {
                  _showWelcome = true;
                  messages.clear();
                  messageGroups.clear();
                });
              },
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () {
              context.pushNamed(RouteConstants.history);
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Main content area
            Expanded(
              child: _showWelcome ? _buildWelcomeScreen() : _buildChatScreen(),
            ),

            // Search bar at the bottom
            BotSearchBar(
              onMessageSent: _handleMessageSent,
              onTyping: _handleTyping,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeScreen() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "Hello! 👋",
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              "How can I help you today?",
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            _buildSuggestedQuestions(),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestedQuestions() {
    final suggestions = [
      "What are the symptoms of diabetes?",
      "How can I improve my sleep quality?",
      "What foods are good for heart health?",
      "How to manage stress effectively?",
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Try asking:",
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: suggestions.map((suggestion) {
            return InkWell(
              onTap: () {
                final message = Message(
                  type: MessageType.text,
                  sender: MessageSender.user,
                  text: suggestion,
                );
                _handleMessageSent(message);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.grey[300]!, width: 1),
                ),
                child: Text(
                  suggestion,
                  style: const TextStyle(fontSize: 13, color: Colors.black87),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildChatScreen() {
    return ListView.separated(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      itemBuilder: (context, index) =>
          ChatMessageWidget(group: messageGroups[index]),
      separatorBuilder: (context, index) => const SizedBox(height: 24),
      itemCount: messageGroups.length,
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
}
