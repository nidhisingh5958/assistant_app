import 'dart:convert';
import 'package:tiktoken/tiktoken.dart';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'dart:async';
import 'package:tflite_flutter/tflite_flutter.dart';

late Interpreter _interpreter;
bool _isModelLoaded = false;
String _status = "Loading model...";
final enc = getEncoding('gpt2');

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
  }
}

// ---------------------- Helper for GPT-2 ----------------------

// Replace your generateAnswer function with this fixed version:

Future<String> generateAnswer(String prompt, {int maxGenLen = 32}) async {
  await _loadModel();
  if (!_isModelLoaded) throw Exception("Model not loaded yet.");

  List<int> tokens = enc.encode(prompt).toList();
  print("Original tokens: ${tokens.take(10).toList()}...");

  // CRITICAL FIX: DistilGPT-2 typically has vocab size 50257, but let's be safe
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

Future<void> _askQuestion() async {
  final query = _chatController.text.trim();
  if (query.isEmpty) return;

  // Check if model is loaded before proceeding
  if (!_isModelLoaded) {
    setState(() {
      _chatResponse = "Model is still loading. Please wait...";
      _status = "Model not ready yet.";
    });
    return;
  }

  setState(() => _status = "Searching embeddings...");

  try {
    final embeddings = await Embeddings.load();

    // VALIDATE THE MODEL FIRST
    final isValid = await embeddings.validateModel();
    if (!isValid) {
      setState(() {
        _chatResponse =
            "Model validation failed. Check tokenizer compatibility.";
        _status = "Model validation error.";
      });
      return;
    }

    final store = await VectorStore.open(embedSize: 384);

    final queryVec = embeddings.embedTexts([query])[0];
    final results = await store.search(queryVec, topK: 3);
    await store.close();

    if (results.isEmpty) {
      setState(() {
        _chatResponse = "No relevant chunks found.";
        _status = "Q&A done.";
      });
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
        setState(
          () => _chatResponse =
              "The context doesn't contain the answer to your question.",
        );
        return;
      }
      print("Cleaned context:\n$cleanedContext");
      print("User's query: $query");

      setState(() {
        _chatResponse = "Context:\n$cleanedContext\n\nGenerating answer...";
        _status = "Generating answer...";
      });

      final ragPrompt =
          """
      Please answer only using the context if missing say "The context doesn't contain the answer to your question."
      Context: $cleanedContext
      Question: $query
      Answer:
    """;

      // -----------------------------------------this is not working good, using a external api for now-----------------------------------------
      //   final formattedAnswer = await generateAnswer(ragPrompt);
      //   final promptString = ragPrompt.trim();
      //   print("Prompt to LLM:\n$promptString");

      //   final tokens = enc.encode(promptString).toList();
      //   print("First 20 tokens: $tokens");
      //   setState(() {
      //     _chatResponse = formattedAnswer;
      //     _status = "Answer generated.";
      //   });
      // //-------------------------------------------------------------------------------------------------------------------------------------

      // --------------------------------API stuff--------------------------------------------------------------------------------------------------

      final client = http.Client();
      try {
        final request = http.Request(
          "GET",
          Uri.parse(
            "http://10.0.2.2:8000/chat?query=${Uri.encodeComponent(query)}",
          ),
        );

        final streamedResponse = await client.send(request);

        if (streamedResponse.statusCode == 200) {
          print("Response from server:${streamedResponse.statusCode}");
          // Convert to a UTF8 stream
          final stream = streamedResponse.stream.transform(utf8.decoder);

          // Listen to chunks and append them to UI
          await for (final chunk in stream) {
            setState(() {
              _chatResponse += chunk;
            });
          }

          setState(() {
            _status = "Streaming finished ✅";
          });
        } else {
          throw Exception("Failed with status ${streamedResponse.statusCode}");
        }
      } catch (e) {
        setState(() {
          _chatResponse = "❌ Error: $e";
          _status = "Streaming failed.";
        });
      } finally {
        client.close();
      }
      //-----------------------------------------------------------------------------------------------------
    }
  } catch (e) {
    setState(() {
      _chatResponse = "Error during search: $e";
      _status = "Q&A failed.";
    });
  }
}
