// A service to generate text embeddings using a TensorFlow Lite model and a BERT tokenizer.
import 'dart:math';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'tokenizer.dart';

class Embeddings {
  final Interpreter interpreter;
  final BertTokenizer tokenizer;
  final int maxLen;
  final int embedSize;
  late int _modelVocabSize;

  Embeddings._(this.interpreter, this.tokenizer, this.maxLen, this.embedSize);

  static Future<Embeddings> load({
    String modelAsset = 'assets/models/sentence_transformer.tflite',
    String vocabAsset = 'assets/tokenizer/vocab.txt',
    int maxLen = 128,
    int embedSize = 384,
  }) async {
    final interpreter = await Interpreter.fromAsset(modelAsset);
    final tokenizer = await BertTokenizer.fromAsset(vocabAsset);

    // Print model info for debugging
    print("Model input details:");
    for (int i = 0; i < interpreter.getInputTensors().length; i++) {
      final tensor = interpreter.getInputTensor(i);
      print("  Input $i: ${tensor.shape}, type: ${tensor.type}");
    }

    print("Model output details:");
    for (int i = 0; i < interpreter.getOutputTensors().length; i++) {
      final tensor = interpreter.getOutputTensor(i);
      print("  Output $i: ${tensor.shape}, type: ${tensor.type}");
    }

    final embeddings = Embeddings._(interpreter, tokenizer, maxLen, embedSize);

    // all-MiniLM-L6-v2 uses the same vocab as BERT but we need to be more careful
    // The model actually uses vocab size 30522 (standard BERT vocab)
    embeddings._modelVocabSize = 30522;
    print(
      "all-MiniLM-L6-v2 model vocabulary size: ${embeddings._modelVocabSize}",
    );

    return embeddings;
  }

  List<List<double>> embedTexts(List<String> texts) {
    try {
      // Process one text at a time for all-MiniLM-L6-v2 stability
      List<List<double>> allEmbeddings = [];

      for (int i = 0; i < texts.length; i++) {
        print("Processing text ${i + 1}/${texts.length}");
        final embedding = _embedSingle(texts[i]);
        allEmbeddings.add(embedding);
      }

      return allEmbeddings;
    } catch (e, stackTrace) {
      print("Error in embedTexts: $e");
      print("Stack trace: $stackTrace");
      rethrow;
    }
  }

  List<double> _embedSingle(String text) {
    try {
      print(
        "Processing text: '${text.length > 50 ? text.substring(0, 50) + '...' : text}'",
      );

      // Tokenize the text
      final tokens = tokenizer.encode(text, maxLen: maxLen);
      print("Raw tokens (first 10): ${tokens.take(10).toList()}...");

      // Critical fix: Ensure all tokens are within valid range for all-MiniLM-L6-v2
      final validTokens = tokens.map((token) {
        if (token < 0 || token >= _modelVocabSize) {
          // For all-MiniLM-L6-v2, use [UNK] token ID which is typically 100
          return 100;
        }
        return token;
      }).toList();

      // Verify token validity
      final minToken = validTokens.reduce((a, b) => a < b ? a : b);
      final maxToken = validTokens.reduce((a, b) => a > b ? a : b);
      print(
        "Token range: min=$minToken, max=$maxToken (vocab size: $_modelVocabSize)",
      );

      if (maxToken >= _modelVocabSize || minToken < 0) {
        throw Exception("Invalid tokens detected even after cleaning");
      }

      // Create attention mask
      final attentionMask = validTokens.map((id) => id != 0 ? 1 : 0).toList();

      print("Final tokens (first 10): ${validTokens.take(10).toList()}...");

      // Prepare inputs for all-MiniLM-L6-v2 (expects input_ids and attention_mask)
      final inputIds = [validTokens];
      final attentionMasks = [attentionMask];

      // Resize tensors for single input
      interpreter.resizeInputTensor(0, [1, maxLen]); // input_ids
      interpreter.resizeInputTensor(1, [1, maxLen]); // attention_mask
      interpreter.allocateTensors();

      // Prepare output buffer for all-MiniLM-L6-v2 (384-dim embeddings)
      final output = [List<double>.filled(embedSize, 0.0)];

      print("Running inference...");
      interpreter.runForMultipleInputs([inputIds, attentionMasks], {0: output});
      print("Inference completed successfully");

      return output[0];
    } catch (e, stackTrace) {
      print("TensorFlow Lite inference failed: $e");
      print("Stack trace: $stackTrace");

      // Return zero embedding as fallback
      print("Returning zero embedding as fallback");
      return List<double>.filled(embedSize, 0.0);
    }
  }

  // Helper method to validate model compatibility
  Future<bool> validateModel() async {
    try {
      const testText = "This is a test sentence.";
      final embedding = _embedSingle(testText);
      final hasNonZero = embedding.any((val) => val.abs() > 1e-6);
      final embeddingNorm = _calculateNorm(embedding);
      print("Model validation:");
      print("  - Non-zero values: $hasNonZero");
      print("  - Embedding norm: $embeddingNorm");
      print("  - Sample values: ${embedding.take(5).toList()}");
      return hasNonZero && embeddingNorm > 0.01;
    } catch (e) {
      print("Model validation failed: $e");
      return false;
    }
  }

  double _calculateNorm(List<double> vector) {
    double sum = 0.0;
    for (final val in vector) {
      sum += val * val;
    }
    return sum > 0 ? sqrt(sum) : 0.0;
  }
}
