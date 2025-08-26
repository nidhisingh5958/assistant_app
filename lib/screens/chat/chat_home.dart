import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:listen_iq/screens/chat/widgets/bot_search_bar.dart';
import 'package:listen_iq/screens/components/appbar.dart';
import 'package:listen_iq/screens/components/sidemenu.dart';
import '../../services/router_constants.dart';

class ChatHome extends StatefulWidget {
  const ChatHome({super.key});

  @override
  State<ChatHome> createState() => _ChatHomeState();
}

class _ChatHomeState extends State<ChatHome> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final GlobalKey<BotSearchBarState> _searchBarKey =
      GlobalKey<BotSearchBarState>();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      drawer: const SideMenu(),
      appBar: AppHeader(
        title: "ListenIQ",
        onMenuPressed: () {
          final scaffoldState = _scaffoldKey.currentState;
          if (scaffoldState?.hasDrawer == true) {
            scaffoldState!.openDrawer();
          }
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
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Stack(
            children: [
              Column(
                children: [
                  // Expanded area for greeting content
                  Expanded(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "Hello! 👋",
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "How can I help you today?",
                            style: Theme.of(context).textTheme.bodyLarge,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Search bar at the bottom with padding
                  Padding(
                    padding: const EdgeInsets.only(bottom: 24.0),
                    child: BotSearchBar(key: _searchBarKey),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
