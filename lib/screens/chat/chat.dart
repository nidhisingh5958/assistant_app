import 'package:flutter/material.dart';
import 'package:listen_iq/screens/chat/data/messages_bot.dart';
import 'package:listen_iq/screens/chat/entities/message_bot.dart';
import 'package:listen_iq/screens/chat/entities/message_group.dart';
import 'package:listen_iq/screens/chat/widgets/bot_search_bar.dart';
import 'package:listen_iq/screens/chat/widgets/chat_message_widget.dart';
import 'package:listen_iq/screens/components/appbar.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<MessageGroup> messageGroups = [];

  @override
  void initState() {
    super.initState();
    _groupMessages();
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

    setState(() {
      messageGroups = groups;
    });
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
              child: ListView.separated(
                controller: _scrollController,
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                itemBuilder: (context, index) =>
                    ChatMessageWidget(group: messageGroups[index]),
                separatorBuilder: (context, index) => SizedBox(height: 24),
                itemCount: messageGroups.length,
              ),
            ),
            BotSearchBar(),
          ],
        ),
      ),
    );
  }
}



/* Expanded(
                    child: TextFormField(
                      controller: _controller,
                      decoration: InputDecoration(
                        hintText: "Type your health query...",
                        hintStyle:
                            TextStyle(fontSize: 14, color: Colors.grey[500]),
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        filled: true,
                        fillColor: Colors.grey[50],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        suffixIcon: Container(
                          margin: EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary,
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            icon: Icon(Icons.send_rounded, color: Colors.white),
                            onPressed: () {
                              if (_controller.text.isNotEmpty) {
                                setState(() {
                                  messages.add(Message(
                                    type: MessageType.text,
                                    sender: MessageSender.user,
                                    text: _controller.text,
                                  ));
                                  _groupMessages();
                                  _controller.clear();
                                  WidgetsBinding.instance
                                      .addPostFrameCallback((_) {
                                    _scrollController.animateTo(
                                      _scrollController
                                          .position.maxScrollExtent,
                                      duration: Duration(milliseconds: 300),
                                      curve: Curves.easeOut,
                                    );
                                  });
                                });
                              }
                            },
                          ),
                        ),
                      ),
                      style: TextStyle(fontSize: 14),
                      minLines: 1,
                      maxLines: 4,
                    ),
                  ),*/