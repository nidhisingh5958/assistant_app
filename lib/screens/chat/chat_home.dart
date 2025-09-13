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

class _ChatHomeState extends State<ChatHome> with WidgetsBindingObserver {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final ScrollController _scrollController = ScrollController();
  final GlobalKey<BotSearchBarState> _searchBarKey =
      GlobalKey<BotSearchBarState>();

  List<Message> messages = [];
  List<MessageGroup> messageGroups = [];
  bool _showWelcome = true;

  // Performance optimization for on-device processing
  static const int _maxMessagesInMemory = 30; // Limit for memory management
  static const Duration _scrollAnimationDuration = Duration(milliseconds: 250);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      // App going to background - could pause processing
    } else if (state == AppLifecycleState.resumed) {
      // App resumed - could reinitialize search bar if needed
      // _searchBarKey.currentState?.somePublicMethod();
    }
  }

  void _handleMessageSent(Message message) {
    setState(() {
      // First message - switch to chat view
      if (_showWelcome) {
        _showWelcome = false;
      }

      // Handle typing indicator replacement for on-device processing
      if (message.sender == MessageSender.bot && messages.isNotEmpty) {
        final lastMessage = messages.last;
        if (lastMessage.sender == MessageSender.bot &&
            (lastMessage.text?.toLowerCase().contains("processing") == true ||
                lastMessage.text?.contains("...") == true)) {
          messages.removeLast();
        }
      }

      messages.add(message);

      // Memory management for on-device performance
      if (messages.length > _maxMessagesInMemory) {
        final removeCount = messages.length - _maxMessagesInMemory;
        messages.removeRange(0, removeCount);
        debugPrint(
          "🧹 Cleaned up $removeCount old messages for memory optimization",
        );
      }

      _groupMessages();
      _autoScrollToBottom();
    });
  }

  void _handleTyping() {
    // Called when bot starts processing - optional UX enhancements
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

  void _autoScrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: _scrollAnimationDuration,
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _clearChatHistory() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Chat'),
        content: const Text('Are you sure you want to clear the chat history?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _showWelcome = true;
                messages.clear();
                messageGroups.clear();
              });
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  void _handleSuggestedQuestion(String question) {
    final message = Message(
      type: MessageType.text,
      sender: MessageSender.user,
      text: question,
    );
    _handleMessageSent(message);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      drawer: const SideMenu(),
      appBar: AppHeader(
        title: "ListenIQ",
        chatTitle: _showWelcome ? null : "Local Health AI",
        isInChat: !_showWelcome,
        onMenuPressed: () {
          _scaffoldKey.currentState?.openDrawer();
        },
        onBackPressed: _showWelcome ? null : _clearChatHistory,
        actions: [
          if (!_showWelcome)
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Clear Chat',
              onPressed: _clearChatHistory,
            ),
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

            // Search bar (always present)
            BotSearchBar(
              key: _searchBarKey,
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
      padding: const EdgeInsets.all(20.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Logo or icon
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.psychology,
              size: 48,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 24),

          // Welcome text
          Text(
            "Hello! 👋",
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            "I'm your local health assistant, powered by on-device AI",
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),

          // Features
          _buildFeatureList(),
          const SizedBox(height: 32),

          // Suggested questions
          _buildSuggestedQuestions(),
        ],
      ),
    );
  }

  Widget _buildFeatureList() {
    final features = [
      {'icon': Icons.security, 'text': 'Private & Secure'},
      {'icon': Icons.offline_bolt, 'text': 'Works Offline'},
      {'icon': Icons.speed, 'text': 'Fast Processing'},
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: features.map((feature) {
        return Column(
          children: [
            Icon(
              feature['icon'] as IconData,
              color: Theme.of(context).colorScheme.primary,
              size: 24,
            ),
            const SizedBox(height: 8),
            Text(
              feature['text'] as String,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildSuggestedQuestions() {
    final suggestions = [
      "What are the symptoms of diabetes?",
      "How can I improve my sleep quality?",
      "What foods are good for heart health?",
      "How to manage stress effectively?",
      "What is a healthy diet?",
      "How much exercise do I need daily?",
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Try asking:",
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: suggestions.map((suggestion) {
            return InkWell(
              onTap: () => _handleSuggestedQuestion(suggestion),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.grey[300]!, width: 1),
                ),
                child: Text(
                  suggestion,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.black87,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildChatScreen() {
    if (messages.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              "Start your conversation",
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

    return ListView.separated(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      itemBuilder: (context, index) =>
          ChatMessageWidget(group: messageGroups[index]),
      separatorBuilder: (context, index) => const SizedBox(height: 20),
      itemCount: messageGroups.length,
    );
  }
}
