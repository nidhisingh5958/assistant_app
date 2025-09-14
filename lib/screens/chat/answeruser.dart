/* answerUser.dart          // Contains askQuestion() + model functions
    ├── askQuestion(query)   // Main RAG processing function
    ├── loadModel()          // Model loading
    ├── generateAnswer()     // GPT-2 text generation
    └── isModelLoaded       // Status getter*/

import 'package:listen_iq/services/file/embeddings.dart';
import 'package:listen_iq/services/file/vector_store.dart';
import 'package:tiktoken/tiktoken.dart';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'dart:async';

late Interpreter _interpreter;
bool _isModelLoaded = false;
String _status = "Loading model...";
final enc = getEncoding('gpt2');

// Export these variables so other files can access them
bool get isModelLoaded => _isModelLoaded;
String get modelStatus => _status;

Future<void> _loadModel() async {
  try {
    _interpreter = await Interpreter.fromAsset(
      "assets/models/distilgpt2.tflite",
    );
    debugPrint("✅ DistilGPT-2 model loaded!");
    _isModelLoaded = true;
    _status = "Model loaded.";
  } catch (e) {
    debugPrint("❌ Error loading model: $e");
    _isModelLoaded = false;
    _status = "Model failed to load: $e";
  }
}

// Make loadModel accessible from other files
Future<void> loadModel() async {
  await _loadModel();
}

// Add the missing askQuestion function
Future<String> askQuestion(String query) async {
  if (query.isEmpty) return "Please ask a question.";

  // Ensure model is loaded
  if (!_isModelLoaded) {
    await _loadModel();
  }

  // Check if model is loaded before proceeding
  if (!_isModelLoaded) {
    return "Model is still loading or failed to load. Please try again.";
  }

  _status = "Searching embeddings...";

  try {
    final embeddings = await Embeddings.load();

    // VALIDATE THE MODEL FIRST
    final isValid = await embeddings.validateModel();
    if (!isValid) {
      return "Model validation failed. Check tokenizer compatibility.";
    }

    final store = await VectorStore.open(embedSize: 384);
    final queryVec = embeddings.embedTexts([query])[0];
    final results = await store.search(queryVec, topK: 3);
    await store.close();

    if (results.isEmpty) {
      return "I couldn't find relevant information for your question in my knowledge base. Could you try rephrasing your question?";
    } else {
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
        return "The context doesn't contain the answer to your question.";
      }

      print("Cleaned context:\n$cleanedContext");
      print("User's query: $query");

      _status = "Generating answer...";

      final ragPrompt =
          """
Please answer only using the context if missing say "The context doesn't contain the answer to your question."
Context: $cleanedContext
Question: $query
Answer:
""";

      final answer = await generateAnswer(ragPrompt, maxGenLen: 128);
      String cleanedAnswer = answer.trim();

      // Clean up the response to remove the prompt if it appears
      if (cleanedAnswer.contains("Answer:")) {
        final parts = cleanedAnswer.split("Answer:");
        cleanedAnswer = parts.length > 1 ? parts.last.trim() : cleanedAnswer;
      }

      // Remove the context and question if they appear in the response
      if (cleanedAnswer.contains("Context:")) {
        cleanedAnswer = cleanedAnswer.split("Context:").first.trim();
      }

      if (cleanedAnswer.contains("Question:")) {
        cleanedAnswer = cleanedAnswer.split("Question:").first.trim();
      }

      // Remove any remaining prompt artifacts
      cleanedAnswer = cleanedAnswer
          .replaceAll(
            RegExp(r'^(Please answer|Context:|Question:).*', multiLine: true),
            '',
          )
          .trim();

      _status = "Ready";
      return cleanedAnswer.isEmpty
          ? "I couldn't generate a proper response."
          : cleanedAnswer;
    }
  } catch (e) {
    _status = "Error occurred";
    return "Error during search: $e";
  }
}

// ---------------------- Helper for GPT-2 ----------------------

Future<String> generateAnswer(String prompt, {int maxGenLen = 32}) async {
  if (!_isModelLoaded) {
    await _loadModel();
  }

  if (!_isModelLoaded) throw Exception("Model not loaded yet.");

  List<int> tokens = enc.encode(prompt).toList();
  print("Original tokens: ${tokens.take(10).toList()}...");

  // DistilGPT-2 typically has vocab size 50257, but let's be safe
  const int modelVocabSize = 50257; // Standard GPT-2 vocab size
  const int eosToken = 50256;

  // Validate and clamp initial tokens
  tokens = tokens.map((token) {
    if (token < 0 || token >= modelVocabSize) {
      print("Warning: Invalid token $token, replacing with 0 (pad)");
      return 0; // Use pad token as fallback
    }
    return token;
  }).toList();

  print("Validated tokens: ${tokens.take(10).toList()}...");

  // Limit initial prompt length to avoid memory issues
  if (tokens.length > 100) {
    tokens = tokens.sublist(tokens.length - 100); // Keep last 100 tokens
    print("Truncated to last ${tokens.length} tokens");
  }

  for (int step = 0; step < maxGenLen; step++) {
    try {
      int curLen = tokens.length;

      // Prepare input - no need for separate padding, use tokens as-is
      var input = [tokens];

      // Resize to current length dynamically
      _interpreter.resizeInputTensor(0, [1, curLen]);
      _interpreter.allocateTensors();

      // Output [1, curLen, vocabSize]
      var output = List.generate(
        1,
        (_) => List.generate(
          curLen,
          (_) => List<double>.filled(modelVocabSize, 0.0),
        ),
      );

      _interpreter.run(input, output);

      // Get logits for the last token only
      final lastLogits = output[0][curLen - 1];

      // Apply temperature and pick next token
      int nextId = _sampleToken(lastLogits, temperature: 0.8);

      // Validate the predicted token
      if (nextId < 0 || nextId >= modelVocabSize) {
        print(
          "Warning: Model predicted invalid token $nextId, stopping generation",
        );
        break;
      }

      tokens.add(nextId);

      if (nextId == eosToken) {
        print("EOS token encountered, stopping generation");
        break;
      }

      // Safety check: prevent runaway generation
      if (tokens.length > 200) {
        print("Maximum token length reached, stopping generation");
        break;
      }
    } catch (e) {
      print("Error during generation step $step: $e");
      break;
    }
  }

  try {
    final result = enc.decode(tokens);
    print("Generated text length: ${result.length}");
    return result;
  } catch (e) {
    print("Error decoding tokens: $e");
    return "Error generating response: $e";
  }
}

/// Improved token sampling with temperature
int _sampleToken(List<double> logits, {double temperature = 1.0}) {
  if (temperature <= 0.0) {
    return _argmax(logits);
  }

  // Apply temperature
  final scaledLogits = logits.map((x) => x / temperature).toList();

  // Find max for numerical stability
  final maxLogit = scaledLogits.reduce((a, b) => a > b ? a : b);

  // Compute softmax probabilities
  final expLogits = scaledLogits.map((x) => math.exp(x - maxLogit)).toList();
  final sumExp = expLogits.reduce((a, b) => a + b);
  final probs = expLogits.map((x) => x / sumExp).toList();

  // Sample from top-k tokens for better quality
  final topK = 50;
  final indexedProbs = probs
      .asMap()
      .entries
      .map((e) => {'index': e.key, 'prob': e.value})
      .toList();

  indexedProbs.sort((a, b) => b['prob']?.compareTo(a['prob'] ?? 0) ?? 0);
  final topKProbs = indexedProbs.take(topK).toList();

  // Simple random selection from top-K (you might want a proper random generator)
  final rng = math.Random();
  final r = rng.nextDouble();
  double cumProb = 0;
  for (var t in topKProbs) {
    cumProb += t['prob'] as double;
    if (r < cumProb) return t['index'] as int;
  }
  return topKProbs.first['index'] as int; // fallback
}

/// Helper to pick max index (fallback for temperature=0)
int _argmax(List<double> logits) {
  int maxIndex = 0;
  double maxVal = logits[0];
  for (int i = 1; i < logits.length; i++) {
    if (logits[i] > maxVal) {
      maxVal = logits[i];
      maxIndex = i;
    }
  }
  return maxIndex;
}
