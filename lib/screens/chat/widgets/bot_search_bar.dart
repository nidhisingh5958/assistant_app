import 'package:flutter/material.dart';
import 'package:listen_iq/screens/chat/entities/message_bot.dart';

// Import your model manager - adjust path as needed
// import 'package:listen_iq/services/on_device_model_manager.dart';

// For now, including simplified version inline
class OnDeviceModelManager {
  static OnDeviceModelManager? _instance;
  static OnDeviceModelManager get instance =>
      _instance ??= OnDeviceModelManager._();
  OnDeviceModelManager._();

  bool _isReady = false;
  String _status = "Initializing...";

  bool get isReady => _isReady;
  String get status => _status;

  Future<bool> initialize() async {
    _status = "Loading model...";
    await Future.delayed(Duration(seconds: 2)); // Simulate loading
    _isReady = true;
    _status = "Ready • On-device processing";
    return true;
  }

  Future<String> processQuery(String query) async {
    _status = "Processing...";
    await Future.delayed(Duration(milliseconds: 1500)); // Simulate processing
    _status = "Ready • On-device processing";
    return "This is a sample response to: $query";
  }
}

class BotSearchBar extends StatefulWidget {
  final Function(Message)? onMessageSent;
  final VoidCallback? onTyping;

  const BotSearchBar({super.key, this.onMessageSent, this.onTyping});

  @override
  State<BotSearchBar> createState() => BotSearchBarState();
}

class BotSearchBarState extends State<BotSearchBar>
    with WidgetsBindingObserver {
  final TextEditingController _chatController = TextEditingController();
  final OnDeviceModelManager _modelManager = OnDeviceModelManager.instance;

  bool _isLoading = false;
  bool _isListening = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeModel();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _chatController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkModelHealth();
    }
  }

  Future<void> _initializeModel() async {
    await _modelManager.initialize();
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _checkModelHealth() async {
    // Check if model needs refresh
    setState(() {});
  }

  Future<void> _handleQuery() async {
    final query = _chatController.text.trim();
    if (query.isEmpty || !_modelManager.isReady || _isLoading) return;

    // Add user message
    widget.onMessageSent?.call(
      Message(type: MessageType.text, sender: MessageSender.user, text: query),
    );

    // Clear input and set loading state
    _chatController.clear();
    setState(() {
      _isLoading = true;
    });

    // Add processing indicator
    widget.onMessageSent?.call(
      Message(
        type: MessageType.text,
        sender: MessageSender.bot,
        text: "Processing on device...",
      ),
    );
    widget.onTyping?.call();

    try {
      // Process query using model manager
      final response = await _modelManager.processQuery(query);

      // Send bot response
      widget.onMessageSent?.call(
        Message(
          type: MessageType.text,
          sender: MessageSender.bot,
          text: response,
        ),
      );
    } catch (e) {
      // Send error message
      widget.onMessageSent?.call(
        Message(
          type: MessageType.text,
          sender: MessageSender.bot,
          text:
              "I encountered an error processing your question. Please try again.",
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Status indicator
          if (!_modelManager.isReady || _isLoading) _buildStatusIndicator(),

          // Input field
          _buildInputField(),
        ],
      ),
    );
  }

  Widget _buildStatusIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _modelManager.isReady ? Colors.green[50] : Colors.orange[50],
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _modelManager.isReady
              ? Colors.green[200]!
              : Colors.orange[200]!,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!_modelManager.isReady || _isLoading)
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(
                  _modelManager.isReady
                      ? Colors.green[600]!
                      : Colors.orange[600]!,
                ),
              ),
            ),
          if (_modelManager.isReady && !_isLoading)
            Icon(Icons.check_circle, size: 16, color: Colors.green[600]),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              _isLoading ? "Processing..." : _modelManager.status,
              style: TextStyle(
                fontSize: 12,
                color: _modelManager.isReady
                    ? Colors.green[700]
                    : Colors.orange[700],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputField() {
    final isEnabled = _modelManager.isReady && !_isLoading;

    return Row(
      children: [
        Expanded(
          child: TextFormField(
            controller: _chatController,
            enabled: isEnabled,
            decoration: InputDecoration(
              hintText: _getHintText(),
              hintStyle: TextStyle(fontSize: 14, color: Colors.grey[500]),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 12,
              ),
              filled: true,
              fillColor: isEnabled ? Colors.grey[50] : Colors.grey[100],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: BorderSide.none,
              ),
              suffixIcon: _buildSendButton(),
            ),
            style: const TextStyle(fontSize: 14),
            minLines: 1,
            maxLines: 3,
            onFieldSubmitted: (_) => _handleQuery(),
            onChanged: (value) {
              setState(() {}); // Rebuild to update send button state
            },
          ),
        ),
      ],
    );
  }

  String _getHintText() {
    if (_isLoading) return "Processing your question...";
    if (!_modelManager.isReady) return "Initializing AI model...";
    return "Ask about health (private & secure)";
  }

  Widget _buildSendButton() {
    final canSend =
        _modelManager.isReady &&
        !_isLoading &&
        _chatController.text.trim().isNotEmpty;

    return Container(
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: canSend
            ? Theme.of(context).colorScheme.primary
            : Colors.grey[400],
        shape: BoxShape.circle,
      ),
      child: _isLoading
          ? const Padding(
              padding: EdgeInsets.all(8.0),
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            )
          : IconButton(
              icon: const Icon(Icons.send_rounded, color: Colors.white),
              onPressed: canSend ? _handleQuery : null,
            ),
    );
  }

  // Method to check model status (called from parent)
  void checkModelStatus() {
    if (mounted) {
      setState(() {});
    }
  }
}
