import 'package:listen_iq/services/file/embeddings.dart';
import 'package:listen_iq/services/file/vector_store.dart';
import 'package:listen_iq/screens/chat/answerUser.dart';

class RAGService {
  static RAGService? _instance;
  static RAGService get instance => _instance ??= RAGService._internal();
  RAGService._internal();

  bool _isInitialized = false;
  String _status = "Initializing...";

  bool get isInitialized => _isInitialized;
  String get status => _status;

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      _status = "Loading model...";
      await _loadModel();
      _isInitialized = true;
      _status = "Ready";
    } catch (e) {
      _status = "Initialization failed: $e";
      throw e;
    }
  }

  Future<String> processQuery(String query) async {
    if (!_isInitialized) {
      await initialize();
    }

    // Check if model is loaded before proceeding
    if (!_isModelLoaded) {
      return "Model is still loading. Please wait...";
    }

    try {
      _status = "Searching embeddings...";

      final embeddings = await Embeddings.load();

      // Validate the model first
      final isValid = await embeddings.validateModel();
      if (!isValid) {
        _status = "Model validation error.";
        return "Model validation failed. Check tokenizer compatibility.";
      }

      final store = await VectorStore.open(embedSize: 384);
      final queryVec = embeddings.embedTexts([query])[0];
      final results = await store.search(queryVec, topK: 3);
      await store.close();

      if (results.isEmpty) {
        _status = "Ready";
        return "No relevant information found for your question.";
      }

      final cleanedContext = results
          .map(
            (r) => r.text
                .replaceAll(
                  RegExp(r'[^a-zA-Z0-9\s\.,!?]'),
                  '',
                ) // Remove special symbols
                .replaceAll(RegExp(r'\s+'), ' ') // Normalize spaces
                .trim(),
          )
          .join("\n\n")
          .trim();

      if (cleanedContext.isEmpty) {
        _status = "Ready";
        return "The context doesn't contain the answer to your question.";
      }

      _status = "Generating answer...";

      final ragPrompt =
          """
Please answer only using the context if missing say "The context doesn't contain the answer to your question."
Context: $cleanedContext
Question: $query
Answer:
""";

      String answer = await generateAnswer(ragPrompt, maxGenLen: 128);
      answer = answer.trim();

      // Clean up the response to remove the prompt if it appears
      if (answer.contains("Answer:")) {
        final parts = answer.split("Answer:");
        answer = parts.length > 1 ? parts.last.trim() : answer;
      }

      // Remove the context and question if they appear in the response
      if (answer.contains("Context:")) {
        answer = answer.split("Context:").first.trim();
      }

      if (answer.contains("Question:")) {
        answer = answer.split("Question:").first.trim();
      }

      // Remove any remaining prompt artifacts
      answer = answer
          .replaceAll(
            RegExp(r'^(Please answer|Context:|Question:).*', multiLine: true),
            '',
          )
          .trim();

      _status = "Ready";
      return answer.isEmpty ? "I couldn't generate a proper response." : answer;
    } catch (e) {
      _status = "Ready";
      return "Error processing your question: $e";
    }
  }

  void dispose() {
    _isInitialized = false;
    _status = "Disposed";
  }
}
