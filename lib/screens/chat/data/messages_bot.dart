import 'package:listen_iq/screens/chat/entities/message_bot.dart';

List<Message> messages = [
  Message(
    type: MessageType.text,
    sender: MessageSender.bot,
    text: "Hello! How can I help you today?",
  ),
  Message(
    type: MessageType.text,
    sender: MessageSender.user,
    text: "Tell me about some cold and flu home remedies",
  ),
  Message(
    type: MessageType.text,
    sender: MessageSender.bot,
    text: "Sure! Here are some home remedies for cold and flu: \n 1. Ginger",
  ),
  Message(
    type: MessageType.media,
    sender: MessageSender.bot,
    mediaUrl:
        "https://plus.unsplash.com/premium_photo-1675364892892-b0aa1b79b67a?q=80&w=1374&auto=format&fit=crop&ixlib=rb-4.0.3&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D",
  ),
  Message(
    type: MessageType.text,
    sender: MessageSender.bot,
    text:
        "Ginger has antioxidant, antimicrobial, and anti-inflammatory properties. Uses includeTrusted Source reducing muscle pain and managing nausea. Make tea by simmering a few slices of raw ginger root in boiling water. As well as providing hydration, it may soothe muscle pain, ease a sore throat, and reduce nausea if present.",
  ),
  Message(type: MessageType.text, sender: MessageSender.bot, text: "2. Honey"),
  Message(
    type: MessageType.media,
    sender: MessageSender.bot,
    mediaUrl:
        "https://images.unsplash.com/photo-1555035900-54c17f3bc1eb?q=80&w=1325&auto=format&fit=crop&ixlib=rb-4.0.3&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D",
  ),
  Message(
    type: MessageType.text,
    sender: MessageSender.bot,
    text:
        "Honey is a natural sweetener and has antimicrobial properties. It can help soothe a sore throat and relieve coughs. Add honey to hot tea or water, or mix it with lemon juice to make a soothing drink.",
  ),
  Message(type: MessageType.text, sender: MessageSender.bot, text: "3. Garlic"),
  Message(
    type: MessageType.media,
    sender: MessageSender.bot,
    mediaUrl:
        "https://plus.unsplash.com/premium_photo-1666270423754-5b66a5184cc3?q=80&w=1374&auto=format&fit=crop&ixlib=rb-4.0.3&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D",
  ),
  Message(
    type: MessageType.text,
    sender: MessageSender.bot,
    text:
        "Garlic has antimicrobial and immune-boosting properties. It can help reduce the severity of cold symptoms. Add garlic to soups, stews, and teas for an extra immune boost.",
  ),

  // Message(
  //   type: MessageType.text,
  //   sender: MessageSender.user,
  //   text: "I need help with my prescription",
  // ),
  // Message(
  //   type: MessageType.text,
  //   sender: MessageSender.bot,
  //   text: "Sure! Please provide me with your prescription details",
  // ),
  // Message(
  //   type: MessageType.text,
  //   sender: MessageSender.user,
  //   text: "I have attached the prescription",
  // ),
  // Message(
  //   type: MessageType.media,
  //   sender: MessageSender.user,
  //   mediaUrl: "https://example.com/prescription.jpg",
  // ),
  // Message(
  //   type: MessageType.text,
  //   sender: MessageSender.bot,
  //   text: "Thank you! I have received the prescription. I will get back to you shortly.",
  // ),
];
