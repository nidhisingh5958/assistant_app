// A pipeline to process encrypted text files: decrypt, chunk, embed, and store in vector DB.
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'text_chunker.dart';
import 'embeddings.dart';
import 'vector_store.dart';
import 'crypto_service.dart';

class PipelineResult {
  final int totalChunks;
  final int totalEmbeddings;
  final bool refreshed;
  final String message;

  PipelineResult(
    this.totalChunks,
    this.totalEmbeddings,
    this.refreshed,
    this.message,
  );
}

class Pipeline {
  final List<int> aesKey32;
  final TextChunker chunker;

  Pipeline({required this.aesKey32, TextChunker? chunker})
    : chunker = chunker ?? TextChunker();

  Future<String> _getEncFilesDir() async {
    final dir = await getApplicationDocumentsDirectory();
    final encDir = Directory("${dir.path}/enc_files");
    if (!await encDir.exists()) {
      await encDir.create(recursive: true);
    }
    return encDir.path;
  }

  Future<PipelineResult> run() async {
    try {
      // Step 0: Get directory with encrypted files
      final dirPath = await _getEncFilesDir();
      final dir = Directory(dirPath);

      // Step 1: Decrypt .enc files to .txt temporarily
      final encFiles = dir
          .listSync()
          .where((e) => e is File && e.path.endsWith(".enc"))
          .cast<File>()
          .toList();

      if (encFiles.isEmpty) {
        return PipelineResult(0, 0, false, "No .enc files found to process");
      }

      final crypto = CryptoService();
      await crypto.loadKeyDecrypt();

      // Decrypt files temporarily
      List<File> tempTxtFiles = [];
      for (final encFile in encFiles) {
        try {
          await crypto.decryptFile(encFile); // Creates .txt and deletes .enc
          final txtPath = encFile.path.replaceFirst(RegExp(r'\.enc$'), '.txt');
          tempTxtFiles.add(File(txtPath));
        } catch (e) {
          print("❌ Failed to decrypt ${encFile.path}: $e");
        }
      }

      // Step 2: Process text files into chunks
      List<String> allChunks = [];
      List<String> chunkSources = []; // Track which file each chunk came from

      for (var file in tempTxtFiles) {
        final content = await file.readAsString();
        final chunks = chunker.chunkText(content);
        allChunks.addAll(chunks);

        for (int i = 0; i < chunks.length; i++) {
          chunkSources.add(file.path);
        }
      }

      if (allChunks.isEmpty) {
        return PipelineResult(
          0,
          0,
          false,
          "No text content found in decrypted files",
        );
      }

      print(
        "📂 Collected ${allChunks.length} text chunks from ${tempTxtFiles.length} files",
      );

      // Step 3: Generate embeddings
      final embeddings = await Embeddings.load();
      final vectors = embeddings.embedTexts(allChunks);

      print("✅ Generated ${vectors.length} embeddings");

      // Step 4: Store in SQLite-based vector store
      final vectorStore = await VectorStore.open(embedSize: 384);
      await vectorStore.clear();

      // Prepare entries
      List<VectorStoreEntry> entries = [];
      for (int i = 0; i < allChunks.length; i++) {
        entries.add(
          VectorStoreEntry(
            id: 'chunk_$i',
            embedding: vectors[i],
            text: allChunks[i],
            metadata: {'source': chunkSources[i]},
          ),
        );
      }

      // Add all entries in a single transaction
      await vectorStore.addBatch(entries);

      await vectorStore.close();

      print("💾 Stored ${vectors.length} embeddings in vector store");

      // Step 5: Delete temporary .txt files
      for (var file in tempTxtFiles) {
        try {
          if (await file.exists()) {
            await file.delete();
          }
        } catch (e) {
          print("❌ Failed to delete temp file ${file.path}: $e");
        }
      }

      return PipelineResult(
        allChunks.length,
        vectors.length,
        true,
        "Pipeline completed successfully",
      );
    } catch (e, stackTrace) {
      print("❌ Pipeline failed: $e");
      print("Stack trace: $stackTrace");
      return PipelineResult(0, 0, false, "Pipeline failed: $e");
    }
  }
}
