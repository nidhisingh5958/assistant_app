class TextChunker {
  final int chunkSize;

  TextChunker({this.chunkSize = 200}); // default 200 tokens/words per chunk

  List<String> chunkText(String text) {
    final words = text.split(RegExp(r'\s+'));
    List<String> chunks = [];
    for (var i = 0; i < words.length; i += chunkSize) {
      final chunk = words.sublist(
        i,
        i + chunkSize > words.length ? words.length : i + chunkSize,
      );
      chunks.add(chunk.join(" ").trim());
    }
    return chunks;
  }
}
