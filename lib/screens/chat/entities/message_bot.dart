import 'package:flutter/material.dart';

class Message {
  final MessageType type;
  final MessageSender sender;
  final String? text;
  final String? mediaUrl;
  final DateTime timestamp;

  Message({
    required this.type,
    required this.sender,
    this.text,
    this.mediaUrl,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

extension MessageExtension on Message {
  Color get textColor {
    switch (sender) {
      case MessageSender.bot:
        return Colors.white;
      case MessageSender.user:
        return Colors.white;
    }
  }

  Gradient? get backgroundGradient {
    switch (sender) {
      case MessageSender.user:
        return const LinearGradient(
          colors: [Color(0xFFd4145a), Color(0xFF662d8c)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        );
      case MessageSender.bot:
        return const LinearGradient(
          colors: [Colors.black, Color(0xFF424242)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        );
    }
  }

  BorderRadius getBorderRadius({bool isFirst = false, bool isLast = false}) {
    const double radius = 20;
    const double smallRadius = 4;

    switch (sender) {
      case MessageSender.bot:
        return BorderRadius.only(
          topLeft: Radius.circular(isFirst ? radius : smallRadius),
          topRight: Radius.circular(radius),
          bottomLeft: Radius.circular(isLast ? radius : smallRadius),
          bottomRight: Radius.circular(radius),
        );
      case MessageSender.user:
        return BorderRadius.only(
          topLeft: Radius.circular(radius),
          topRight: Radius.circular(isFirst ? radius : smallRadius),
          bottomLeft: Radius.circular(radius),
          bottomRight: Radius.circular(isLast ? radius : smallRadius),
        );
    }
  }
}

enum MessageType { text, media }

enum MessageSender { bot, user }




// import 'package:flutter/material.dart';

// class Message {
//   final MessageType type;
//   final MessageSender sender;
//   final String? text;
//   final String? mediaUrl;

//   const Message({
//     required this.type,
//     required this.sender,
//     this.text,
//     this.mediaUrl,
//   });
// }

// extension MessageExtension on Message {
//   Color get TextColor {
//     switch (sender) {
//       case MessageSender.bot:
//         return Colors.black;
//       case MessageSender.user:
//         return Color(0xFF232729);
//     }
//   }

//   Color get backgroundColor {
//     switch (sender) {
//       case MessageSender.bot:
//         return Color.fromRGBO(162, 210, 255, 1);
//       case MessageSender.user:
//         return Color.fromRGBO(189, 224, 254, 1);
//     }
//   }

//   BorderRadius get borderRadius {
//     switch (sender) {
//       case MessageSender.bot:
//         return BorderRadius.only(
//           topLeft: Radius.circular(20),
//           topRight: Radius.circular(20),
//           bottomLeft: Radius.circular(4),
//           bottomRight: Radius.circular(20),
//         );
//       case MessageSender.user:
//         return BorderRadius.only(
//           topLeft: Radius.circular(20),
//           topRight: Radius.circular(20),
//           bottomLeft: Radius.circular(20),
//           bottomRight: Radius.circular(4),
//         );
//     }
//   }
// }

// enum MessageType { text, media }

// enum MessageSender { bot, user }