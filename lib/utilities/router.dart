import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:listen_iq/screens/chat/chat.dart';
import 'package:listen_iq/screens/chat/chat_home.dart';
import 'package:listen_iq/screens/settings/contact_us.dart';
import 'package:listen_iq/screens/settings/terms_and_conditions.dart';
import 'package:listen_iq/screens/history.dart';
import 'package:listen_iq/screens/home.dart';
import 'package:listen_iq/screens/video_assistant/camera_screen.dart';
import 'package:listen_iq/screens/voice_assistant/voice_assistant.dart';
import 'package:listen_iq/utilities/router_constants.dart';

final GoRouter router = GoRouter(
  initialLocation: '/home',
  routes: <RouteBase>[
    GoRoute(
      path: '/home',
      name: RouteConstants.home,
      builder: (BuildContext context, GoRouterState state) {
        return HomeScreen();
      },
      routes: <RouteBase>[
        GoRoute(
          path: '/voiceAssistant',
          name: RouteConstants.voiceAssistant,
          builder: (BuildContext context, GoRouterState state) {
            return VoiceAssistantScreen();
          },
        ),
        GoRoute(
          path: '/videoAssistant',
          name: RouteConstants.videoAssistant,
          builder: (BuildContext context, GoRouterState state) {
            return CameraScreen(cameras: []);
          },
        ),
        GoRoute(
          path: '/chat_home',
          name: RouteConstants.chatHome,
          builder: (BuildContext context, GoRouterState state) {
            return ChatHome();
          },
          routes: <RouteBase>[
            GoRoute(
              path: '/chat',
              name: RouteConstants.chat,
              builder: (BuildContext context, GoRouterState state) {
                return ChatScreen();
              },
            ),
          ],
        ),
        GoRoute(
          path: '/history',
          name: RouteConstants.history,
          builder: (BuildContext context, GoRouterState state) {
            return HistoryScreen();
          },
        ),
        GoRoute(
          path: '/termsAndConditions',
          name: RouteConstants.termsAndConditions,
          builder: (BuildContext context, GoRouterState state) {
            return TermsAndConditionsScreen();
          },
        ),
        GoRoute(
          path: '/contactUs',
          name: RouteConstants.contactUs,
          builder: (BuildContext context, GoRouterState state) {
            return ReportProblemScreen();
          },
        ),
      ],
    ),
    // GoRoute(
    //   path: '/settings',
    //   name: RouteConstants.settings,
    //   builder: (BuildContext context, GoRouterState state) {
    //     return SettingsScreen();
    //   },
    // ),
  ],
);
