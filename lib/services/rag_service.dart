import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:listen_iq/services/file/embeddings.dart';
import 'package:listen_iq/services/file/vector_store.dart';
import 'package:listen_iq/screens/chat/answerUser.dart';
import 'package:listen_iq/screens/chat/entities/message_bot.dart';

/// Enhanced RAG Service with better error handling and streaming responses
class RAGService {
  static RAGService? _instance;
  static RAGService get instance => _instance ??= RAGService._internal();
  RAGService._internal();

  bool _isInitialized = false;
  bool _isInitializing = false;
  bool _isModelLoaded = false;
  String _status = "Not initialized";
  StreamController<String>? _statusController;

  // Performance metrics
  int _queryCount = 0;
  List<int> _responseTimes = [];

  bool get isInitialized => _isInitialized;
  String get status => _status;
  bool get isInitializing => _isInitializing;
  Stream<String> get statusStream =>
      _statusController?.stream ?? Stream.empty();

  Future<bool> initialize() async {
    if (_isInitialized || _isInitializing) return _isInitialized;

    _isInitializing = true;
    _statusController = StreamController<String>.broadcast();

    try {
      _updateStatus("Loading DistilGPT-2 model...");

      // Load the TensorFlow Lite model
      await _loadModel();

      if (_isModelLoaded) {
        _updateStatus("Testing model inference...");

        // Test the model with a simple prompt
        await _testModelInference();

        _isInitialized = true;
        _updateStatus("Model ready - AI assistant online!");

        debugPrint("✅ RAG Service initialized successfully");
        return true;
      } else {
        throw Exception("Model failed to load");
      }
    } catch (e) {
      _updateStatus("Initialization failed");
      debugPrint("❌ RAG Service initialization failed: $e");
      return false;
    } finally {
      _isInitializing = false;
    }
  }

  Future<void> _loadModel() async {
    try {
      // Simulate model loading - replace with actual model loading logic
      await Future.delayed(const Duration(milliseconds: 500));
      _isModelLoaded = true;
    } catch (e) {
      _isModelLoaded = false;
      throw Exception("Failed to load model: $e");
    }
  }

  Future<void> _testModelInference() async {
    try {
      await generateAnswer("Test prompt:", maxGenLen: 3);
    } catch (e) {
      throw Exception("Model inference test failed: $e");
    }
  }

  void _updateStatus(String newStatus) {
    _status = newStatus;
    _statusController?.add(newStatus);
    debugPrint("RAG Status: $newStatus");
  }

  /// Process a health-related query using RAG pipeline
  Future<Message> processHealthQuery(String query) async {
    if (!_isInitialized) {
      return Message(
        type: MessageType.text,
        sender: MessageSender.bot,
        text: "I'm still initializing. Please wait a moment and try again.",
      );
    }

    final stopwatch = Stopwatch()..start();
    _queryCount++;

    try {
      _updateStatus("Searching knowledge base...");

      // Step 1: Load embeddings and validate
      final embeddings = await Embeddings.load();

      if (!await embeddings.validateModel()) {
        return Message(
          type: MessageType.text,
          sender: MessageSender.bot,
          text:
              "I'm experiencing technical difficulties. Please try again later.",
        );
      }

      // Step 2: Vector search for relevant context
      final store = await VectorStore.open(embedSize: 384);
      final queryVec = embeddings.embedTexts([query])[0];
      final results = await store.search(queryVec, topK: 3);
      await store.close();

      if (results.isEmpty) {
        return Message(
          type: MessageType.text,
          sender: MessageSender.bot,
          text:
              "I don't have information about that specific topic in my knowledge base. Could you try rephrasing your question or ask about general health topics?",
        );
      }

      // Step 3: Prepare clean context
      final cleanedContext = _prepareContext(results);

      if (cleanedContext.isEmpty) {
        return Message(
          type: MessageType.text,
          sender: MessageSender.bot,
          text:
              "I found some information but it's not clear enough to provide a reliable answer. Please try asking more specific questions.",
        );
      }

      _updateStatus("Generating response...");

      // Step 4: Generate response using RAG
      final response = await _generateRAGResponse(query, cleanedContext);

      // Record performance metrics
      stopwatch.stop();
      _responseTimes.add(stopwatch.elapsedMilliseconds);
      if (_responseTimes.length > 10) {
        _responseTimes.removeAt(0);
      }

      _updateStatus("Ready");

      return Message(
        type: MessageType.text,
        sender: MessageSender.bot,
        text: response,
      );
    } catch (e) {
      stopwatch.stop();
      _updateStatus("Ready");

      debugPrint("❌ Query processing failed: $e");

      return Message(
        type: MessageType.text,
        sender: MessageSender.bot,
        text:
            "I encountered an error while processing your question. This might be due to a complex query or temporary processing issues. Please try asking a simpler question.",
      );
    }
  }

  String _prepareContext(List<dynamic> results) {
    return results
        .map(
          (r) => r.text
              .replaceAll(
                RegExp(r'[^\w\s\.,!?-]'),
                '',
              ) // Keep basic punctuation
              .replaceAll(RegExp(r'\s+'), ' ') // Normalize whitespace
              .trim(),
        )
        .where((text) => text.isNotEmpty)
        .join('\n\n')
        .trim();
  }

  Future<String> _generateRAGResponse(String query, String context) async {
    final prompt = _buildHealthPrompt(query, context);

    try {
      String response = await generateAnswer(prompt, maxGenLen: 150);
      return _cleanResponse(response, query);
    } catch (e) {
      debugPrint("Response generation error: $e");
      return "I apologize, but I'm having trouble generating a response right now. Please try again.";
    }
  }

  String _buildHealthPrompt(String query, String context) {
    return """You are a helpful health information assistant. Answer the user's question using only the provided context. Be concise, accurate, and helpful.

Context: $context

Question: $query

Instructions:
- Only use information from the context above
- If the context doesn't contain the answer, say so clearly
- Keep responses focused and under 3 sentences when possible
- Avoid medical advice - provide general information only

Answer:""";
  }

  String _cleanResponse(String response, String originalQuery) {
    // Remove prompt artifacts
    response = response.split('Answer:').last.trim();

    // Remove context/question if they leaked into response
    final cleanPatterns = [
      RegExp(r'^(Context:|Question:|Instructions:).*$', multiLine: true),
      RegExp(r'^(You are a|Answer the user).*$', multiLine: true),
    ];

    for (final pattern in cleanPatterns) {
      response = response.replaceAll(pattern, '').trim();
    }

    // Ensure minimum quality
    if (response.length < 10 ||
        response.toLowerCase().contains('context') && response.length < 50) {
      return "I found some relevant information, but I'm having trouble providing a clear answer. Could you try rephrasing your question?";
    }

    return response;
  }

  // Performance and status methods
  int get queryCount => _queryCount;
  double get averageResponseTime {
    if (_responseTimes.isEmpty) return 0.0;
    return _responseTimes.reduce((a, b) => a + b) / _responseTimes.length;
  }

  void dispose() {
    _statusController?.close();
    _isInitialized = false;
    _status = "Disposed";
  }
}
