import 'package:tflite_flutter/tflite_flutter.dart';
import 'tokenizer.dart';

class Embeddings {
  final Interpreter interpreter;
  final BertTokenizer tokenizer;
  final int maxLen;
  final int embedSize;

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
    print("🔍 Model input details:");
    for (int i = 0; i < interpreter.getInputTensors().length; i++) {
      final tensor = interpreter.getInputTensor(i);
      print("  Input $i: ${tensor.shape}, type: ${tensor.type}");
    }
    
    print("🔍 Model output details:");
    for (int i = 0; i < interpreter.getOutputTensors().length; i++) {
      final tensor = interpreter.getOutputTensor(i);
      print("  Output $i: ${tensor.shape}, type: ${tensor.type}");
    }
    
    return Embeddings._(interpreter, tokenizer, maxLen, embedSize);
  }

  /// Embed multiple texts at once with better error handling
  List<List<double>> embedTexts(List<String> texts) {
    try {
      // Process texts in smaller batches to avoid memory issues
      const batchSize = 4; // Reduced batch size
      List<List<double>> allEmbeddings = [];
      
      for (int start = 0; start < texts.length; start += batchSize) {
        final end = (start + batchSize < texts.length) ? start + batchSize : texts.length;
        final batch = texts.sublist(start, end);
        
        print("🔄 Processing batch ${start ~/ batchSize + 1}/${(texts.length / batchSize).ceil()}: ${batch.length} texts");
        
        final batchEmbeddings = _embedBatch(batch);
        allEmbeddings.addAll(batchEmbeddings);
      }
      
      return allEmbeddings;
    } catch (e, stackTrace) {
      print("❌ Error in embedTexts: $e");
      print("Stack trace: $stackTrace");
      rethrow;
    }
  }

  // ... (rest of the file unchanged)

List<List<double>> _embedBatch(List<String> texts) {
  final int batchSize = texts.length;
  final List<List<int>> inputIds = [];
  final List<List<int>> attentionMasks = [];

  for (int i = 0; i < texts.length; i++) {
    final text = texts[i];
    print("🔤 Processing text $i: '${text.length > 50 ? text.substring(0, 50) + '...' : text}'");

    try {
      // Use tokenizer.encode directly (it already handles CLS/SEP/padding)
      final tokens = tokenizer.encode(text, maxLen: maxLen);
      print("🔢 Tokens (first 10): ${tokens.take(10).toList()}...");

      // Validate token IDs
      final invalidTokens = tokens.where((token) => token < 0 || token >= tokenizer.vocabSize).toList();
      if (invalidTokens.isNotEmpty) {
        print("⚠️ Warning: Found invalid tokens: $invalidTokens");
        // Replace invalid with UNK (assume ID 100 for BERT-like models)
        final cleanedTokens = tokens.map((t) => (t < 0 || t >= tokenizer.vocabSize) ? 100 : t).toList();
        inputIds.add(cleanedTokens);
      } else {
        inputIds.add(tokens);
      }

      // Create attention mask: 1 for non-pad (id != 0), 0 for pad
      final mask = tokens.map((id) => id != 0 ? 1 : 0).toList();
      attentionMasks.add(mask);

      print("🎯 Final tokens (first 10): ${tokens.take(10).toList()}...");
    } catch (e) {
      print("❌ Error tokenizing text $i: $e");
      // Fallback: empty input with CLS/SEP
      final safeTokens = List<int>.filled(maxLen, 0);
      safeTokens[0] = 101; // CLS
      safeTokens[1] = 102; // SEP
      inputIds.add(safeTokens);
      attentionMasks.add(safeTokens.map((id) => id != 0 ? 1 : 0).toList());
    }
  }

  try {
    print("📊 Input tensor shape: [$batchSize, $maxLen]");

    // Resize tensors for current batch (essential for dynamic shapes)
    interpreter.resizeInputTensor(0, [batchSize, maxLen]);
    interpreter.resizeInputTensor(1, [batchSize, maxLen]);
    interpreter.allocateTensors();

    // Prepare output buffer
    final output = List.generate(batchSize, (_) => List<double>.filled(embedSize, 0.0));

    // Run inference with BOTH inputs
    print("🚀 Running inference...");
    interpreter.runForMultipleInputs([inputIds, attentionMasks], {0: output});
    print("✅ Inference completed successfully");

    return output;
  } catch (e, stackTrace) {
    print("❌ TensorFlow Lite inference failed: $e");
    print("Stack trace: $stackTrace");
    // Fallback zero embeddings
    print("🔄 Returning zero embeddings as fallback");
    return List.generate(batchSize, (_) => List<double>.filled(embedSize, 0.0));
  }
}

}