// services/vector_store.dart
import 'dart:io';
import 'dart:convert';
import 'dart:math';
import 'package:path_provider/path_provider.dart';

class VectorSearchResult {
  final String id;
  final String text;
  final Map<String, dynamic> metadata;
  final double similarity;

  VectorSearchResult({
    required this.id,
    required this.text,
    required this.metadata,
    required this.similarity,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'text': text,
    'metadata': metadata,
    'similarity': similarity,
  };

  factory VectorSearchResult.fromJson(Map<String, dynamic> json) => VectorSearchResult(
    id: json['id'],
    text: json['text'],
    metadata: Map<String, dynamic>.from(json['metadata'] ?? {}),
    similarity: json['similarity']?.toDouble() ?? 0.0,
  );
}

class VectorStoreEntry {
  final String id;
  final List<double> embedding;
  final String text;
  final Map<String, dynamic> metadata;

  VectorStoreEntry({
    required this.id,
    required this.embedding,
    required this.text,
    required this.metadata,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'embedding': embedding,
    'text': text,
    'metadata': metadata,
  };

  factory VectorStoreEntry.fromJson(Map<String, dynamic> json) => VectorStoreEntry(
    id: json['id'],
    embedding: List<double>.from(json['embedding']),
    text: json['text'],
    metadata: Map<String, dynamic>.from(json['metadata'] ?? {}),
  );
}

class VectorStore {
  final int embedSize;
  final String _dbPath;
  final List<VectorStoreEntry> _entries = [];

  VectorStore._(this.embedSize, this._dbPath);

  static Future<VectorStore> open({required int embedSize}) async {
    final dir = await getApplicationDocumentsDirectory();
    final dbPath = "${dir.path}/vector_store.json";
    final store = VectorStore._(embedSize, dbPath);
    await store._load();
    return store;
  }

  Future<void> _load() async {
    final file = File(_dbPath);
    if (await file.exists()) {
      try {
        final content = await file.readAsString();
        final jsonData = json.decode(content) as Map<String, dynamic>;
        final entries = jsonData['entries'] as List?;
        
        if (entries != null) {
          _entries.clear();
          for (final entryJson in entries) {
            _entries.add(VectorStoreEntry.fromJson(entryJson));
          }
        }
        print("📖 Loaded ${_entries.length} vectors from database");
      } catch (e) {
        print("⚠️ Error loading vector store: $e");
        _entries.clear();
      }
    }
  }

  Future<void> _save() async {
    final file = File(_dbPath);
    final data = {
      'embedSize': embedSize,
      'entries': _entries.map((e) => e.toJson()).toList(),
    };
    await file.writeAsString(json.encode(data));
  }

  Future<void> add({
    required String id,
    required List<double> embedding,
    required String text,
    Map<String, dynamic>? metadata,
  }) async {
    if (embedding.length != embedSize) {
      throw ArgumentError('Embedding size ${embedding.length} does not match expected $embedSize');
    }

    // Remove existing entry with same ID if it exists
    _entries.removeWhere((entry) => entry.id == id);

    // Add new entry
    _entries.add(VectorStoreEntry(
      id: id,
      embedding: embedding,
      text: text,
      metadata: metadata ?? {},
    ));

    await _save();
  }

  Future<List<VectorSearchResult>> search(List<double> queryEmbedding, {int topK = 5}) async {
    if (queryEmbedding.length != embedSize) {
      throw ArgumentError('Query embedding size ${queryEmbedding.length} does not match expected $embedSize');
    }

    if (_entries.isEmpty) {
      return [];
    }

    // Calculate cosine similarities
    final results = <VectorSearchResult>[];
    
    for (final entry in _entries) {
      final similarity = _cosineSimilarity(queryEmbedding, entry.embedding);
      results.add(VectorSearchResult(
        id: entry.id,
        text: entry.text,
        metadata: entry.metadata,
        similarity: similarity,
      ));
    }

    // Sort by similarity (descending) and take top K
    results.sort((a, b) => b.similarity.compareTo(a.similarity));
    
    return results.take(topK).toList();
  }

  double _cosineSimilarity(List<double> a, List<double> b) {
    if (a.length != b.length) {
      throw ArgumentError('Vector dimensions must match');
    }

    double dotProduct = 0.0;
    double normA = 0.0;
    double normB = 0.0;

    for (int i = 0; i < a.length; i++) {
      dotProduct += a[i] * b[i];
      normA += a[i] * a[i];
      normB += b[i] * b[i];
    }

    if (normA == 0.0 || normB == 0.0) {
      return 0.0;
    }

    return dotProduct / (sqrt(normA) * sqrt(normB));
  }

  Future<void> clear() async {
    _entries.clear();
    await _save();
  }

  Future<void> close() async {
    await _save();
  }

  int get count => _entries.length;
}