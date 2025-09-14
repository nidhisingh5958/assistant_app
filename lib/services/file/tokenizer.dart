// Takes only relevant parts from the speech and removes words like is, am, the, a, an, etc.
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

class BertTokenizer {
  late final Map<String, int> vocab;
  final String unkToken;
  final bool doLowerCase;

  BertTokenizer._(
    this.vocab, {
    this.unkToken = "[UNK]",
    this.doLowerCase = true,
  });

  static Future<BertTokenizer> fromAsset(
    String assetPath, {
    String unkToken = "[UNK]",
    bool doLowerCase = true,
  }) async {
    final vocabText = await rootBundle.loadString(assetPath);
    final lines = const LineSplitter().convert(vocabText);
    final map = <String, int>{};
    for (var i = 0; i < lines.length; i++) {
      map[lines[i].trim()] = i;
    }
    return BertTokenizer._(map, unkToken: unkToken, doLowerCase: doLowerCase);
  }

  /// Returns vocab size
  int get vocabSize => vocab.length;

  /// Encodes text into token IDs, padded/truncated to [maxLen].
  List<int> encode(String text, {int maxLen = 128}) {
    final tokens = _tokenize(text);
    final wp = ["[CLS]", ...tokens, "[SEP]"];
    final ids = wp.map((t) => vocab[t] ?? vocab[unkToken]!).toList();

    // Pad/truncate
    final padded = List<int>.filled(maxLen, vocab["[PAD]"] ?? 0);
    for (int i = 0; i < ids.length && i < maxLen; i++) {
      padded[i] = ids[i];
    }
    return padded;
  }

  List<String> _tokenize(String text) {
    String t = doLowerCase ? text.toLowerCase() : text;
    t = t.replaceAll(RegExp(r'\s+'), ' ').trim();
    final words = t.split(RegExp(r"\s+")).where((w) => w.isNotEmpty).toList();

    final List<String> output = [];
    for (final w in words) {
      output.addAll(_wordpiece(w));
    }
    return output;
  }

  List<String> _wordpiece(String token) {
    if (vocab.containsKey(token)) return [token];
    final List<String> subTokens = [];
    int start = 0;

    while (start < token.length) {
      int end = token.length;
      String curSubStr = "";
      bool found = false;

      while (start < end) {
        var substr = token.substring(start, end);
        if (start > 0) substr = "##$substr";
        if (vocab.containsKey(substr)) {
          curSubStr = substr;
          found = true;
          break;
        }
        end -= 1;
      }

      if (!found || curSubStr.isEmpty) {
        // Fallback: add UNK for this part and advance by 1 char to avoid infinite loop
        subTokens.add(unkToken);
        start += 1; // Advance minimally
      } else {
        subTokens.add(curSubStr);
        start = end;
      }
    }
    return subTokens;
  }
}

// Debug helper for tokenizer issues
// Add this to your tokenizer.dart or create a separate debug file

class TokenizerDebugger {
  final BertTokenizer tokenizer;

  TokenizerDebugger(this.tokenizer);

  void debugTokenization(String text) {
    print("🔍 Debugging tokenization for: '$text'");

    try {
      final tokens = tokenizer.encode(text);
      print("📝 Original tokens: $tokens");
      print("📊 Token count: ${tokens.length}");
      print("🆔 Vocab size: ${tokenizer.vocabSize}");

      // Check for out-of-bounds tokens
      final invalidTokens = <int>[];
      for (int i = 0; i < tokens.length; i++) {
        if (tokens[i] < 0 || tokens[i] >= tokenizer.vocabSize) {
          invalidTokens.add(tokens[i]);
        }
      }

      if (invalidTokens.isNotEmpty) {
        print("❌ Found ${invalidTokens.length} invalid tokens: $invalidTokens");
      } else {
        print("✅ All tokens are valid");
      }

      // Check for special tokens
      final specialTokens = {
        0: 'PAD',
        1: 'UNK',
        101: 'CLS',
        102: 'SEP',
        103: 'MASK',
      };

      print("🏷️ Special tokens found:");
      for (int token in tokens) {
        if (specialTokens.containsKey(token)) {
          print("  $token -> ${specialTokens[token]}");
        }
      }
    } catch (e, stackTrace) {
      print("❌ Tokenization failed: $e");
      print("Stack trace: $stackTrace");
    }
  }

  void testBasicTokenization() {
    print("🧪 Running basic tokenization tests...");

    final testTexts = [
      "hello world",
      "artificial intelligence",
      "machine learning algorithms",
      "", // empty string
      "a", // single character
      "This is a longer sentence with multiple words to test tokenization.",
    ];

    for (String text in testTexts) {
      debugTokenization(text);
      print("---");
    }
  }
}
