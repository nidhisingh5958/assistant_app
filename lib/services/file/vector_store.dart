// services/vector_store.dart
import 'dart:convert';
import 'dart:math';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart';

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

  factory VectorSearchResult.fromJson(Map<String, dynamic> json) =>
      VectorSearchResult(
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

  factory VectorStoreEntry.fromJson(Map<String, dynamic> json) =>
      VectorStoreEntry(
        id: json['id'],
        embedding: List<double>.from(json['embedding']),
        text: json['text'],
        metadata: Map<String, dynamic>.from(json['metadata'] ?? {}),
      );
}

class VectorStore {
  final int embedSize;
  late final Database _db;

  VectorStore._(this.embedSize);

  /// Open or create the SQLite database
  static Future<VectorStore> open({required int embedSize}) async {
    final store = VectorStore._(embedSize);
    await store._initDb();
    return store;
  }

  Future<void> _initDb() async {
    final documentsDir = await getApplicationDocumentsDirectory();
    final path = join(documentsDir.path, 'vector_store.db');

    _db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE vector_store (
            id TEXT PRIMARY KEY,
            embedding TEXT,
            text TEXT,
            metadata TEXT
          )
        ''');
      },
    );
    print("📖 VectorStore initialized at $path");
  }

  /// Add or update a vector entry
  Future<void> add({
    required String id,
    required List<double> embedding,
    required String text,
    Map<String, dynamic>? metadata,
  }) async {
    if (embedding.length != embedSize) {
      throw ArgumentError(
          'Embedding size ${embedding.length} does not match expected $embedSize');
    }

    await _db.insert(
      'vector_store',
      {
        'id': id,
        'embedding': jsonEncode(embedding),
        'text': text,
        'metadata': jsonEncode(metadata ?? {}),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }


  // Inside VectorStore class
Future<void> addBatch(List<VectorStoreEntry> entries) async {
  await _db.transaction((txn) async {
    for (final entry in entries) {
      await txn.insert(
        'vector_store',
        {
          'id': entry.id,
          'embedding': jsonEncode(entry.embedding),
          'text': entry.text,
          'metadata': jsonEncode(entry.metadata),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  });
}
  /// Search for top K most similar vectors
  Future<List<VectorSearchResult>> search(List<double> queryEmbedding,
      {int topK = 5}) async {
    if (queryEmbedding.length != embedSize) {
      throw ArgumentError(
          'Query embedding size ${queryEmbedding.length} does not match expected $embedSize');
    }

    final rows = await _db.query('vector_store');
    if (rows.isEmpty) return [];

    final results = <VectorSearchResult>[];

    for (final row in rows) {
      final embedding =
          List<double>.from(jsonDecode(row['embedding'] as String));
      final similarity = _cosineSimilarity(queryEmbedding, embedding);

      results.add(VectorSearchResult(
        id: row['id'] as String,
        text: row['text'] as String,
        metadata: Map<String, dynamic>.from(
            jsonDecode(row['metadata'] as String)),
        similarity: similarity,
      ));
    }

    results.sort((a, b) => b.similarity.compareTo(a.similarity));
    return results.take(topK).toList();
  }

  /// Clear all entries
  Future<void> clear() async {
    await _db.delete('vector_store');
  }

  /// Close the database
  Future<void> close() async {
    await _db.close();
  }

  /// Count of entries
  Future<int> get count async {
    final x = Sqflite.firstIntValue(
        await _db.rawQuery('SELECT COUNT(*) FROM vector_store'));
    return x ?? 0;
  }

  /// Cosine similarity helper
  double _cosineSimilarity(List<double> a, List<double> b) {
    double dotProduct = 0.0;
    double normA = 0.0;
    double normB = 0.0;

    for (int i = 0; i < a.length; i++) {
      dotProduct += a[i] * b[i];
      normA += a[i] * a[i];
      normB += b[i] * b[i];
    }

    if (normA == 0.0 || normB == 0.0) return 0.0;

    return dotProduct / (sqrt(normA) * sqrt(normB));
  }
}
