// A service to handle AES-GCM file encryption and decryption with key management.
import 'dart:io';
import 'dart:typed_data';
import 'dart:math';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class CryptoService {
  static const String _keyFileName = "thekey.key";
  static const int _keyLength = 32; // AES-256 requires 32 bytes

  late Uint8List _keyBytes;

  /// Initialize service: load or generate key
  Future<void> loadKeyEncrypt() async {
    final dir = await getApplicationDocumentsDirectory();
    final keyFile = File('${dir.path}/$_keyFileName');

    if (await keyFile.exists()) {
      _keyBytes = await keyFile.readAsBytes();
      print("Key loaded from: ${keyFile.path}");
    } else {
      _keyBytes = _generateRandomKey(_keyLength);
      await keyFile.writeAsBytes(_keyBytes, flush: true);
      print("New key generated and saved at: ${keyFile.path}");
    }
  }

  /// Load the encryption key for decryption
  Future<void> loadKeyDecrypt() async {
    final dir = await getApplicationDocumentsDirectory();
    final keyFile = File('${dir.path}/$_keyFileName');

    if (await keyFile.exists()) {
      _keyBytes = await keyFile.readAsBytes();
      print("Key loaded for decryption from: ${keyFile.path}");
    } else {
      throw Exception("Key file not found");
    }
  }

  /// Generate random AES key
  Uint8List _generateRandomKey(int length) {
    final rand = Random.secure();
    return Uint8List.fromList(
      List<int>.generate(length, (_) => rand.nextInt(256)),
    );
  }

  /// Encrypt a file -> save as .enc
  Future<void> encryptFile(File inputFile, String outputPath) async {
    final key = enc.Key(_keyBytes);
    print("Encrypting file: ${inputFile.path}");

    // AES-GCM prefers random 12-byte IV
    final iv = enc.IV.fromSecureRandom(12);
    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.gcm));

    final inputBytes = await inputFile.readAsBytes();
    final encrypted = encrypter.encryptBytes(inputBytes, iv: iv);

    // Save format: [IV][CIPHERTEXT+TAG]
    final outBytes = iv.bytes + encrypted.bytes;
    final outFile = File(outputPath);
    await outFile.writeAsBytes(outBytes, flush: true);

    print("File encrypted: ${outFile.path}");
  }

  /// Decrypt a file -> restore original
  Future<File> decryptFile(File encFile, {String? outputPath}) async {
    final key = enc.Key(_keyBytes);
    final content = await encFile.readAsBytes();

    if (content.length < 12 + 16) {
      throw Exception("Invalid encrypted file: ${encFile.path}");
    }

    // [IV (12 bytes)] + [Ciphertext+Tag]
    final iv = enc.IV(content.sublist(0, 12));
    final cipherAndTag = content.sublist(12);

    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.gcm));
    final decrypted = encrypter.decryptBytes(
      enc.Encrypted(cipherAndTag),
      iv: iv,
    );

    final outPath = outputPath ?? p.setExtension(encFile.path, '.txt');
    final outFile = File(outPath);

    await outFile.writeAsBytes(decrypted, flush: true);

    // Remove the encrypted file only if decryption succeeded
    try {
      await encFile.delete();
      print("Deleted encrypted file: ${encFile.path}");
    } catch (e) {
      print("⚠️ Could not delete encrypted file: ${encFile.path} — $e");
    }

    print("File decrypted: ${outFile.path}");
    return outFile;
  }

  /// Decrypt all `.enc` files in a directory
  Future<int> decryptDirectory(String dirPath) async {
    final dir = Directory(dirPath);
    if (!await dir.exists()) return 0;

    final files = await dir
        .list()
        .where((e) => e is File && e.path.endsWith('.enc'))
        .cast<File>()
        .toList();

    int count = 0;
    for (final f in files) {
      try {
        await decryptFile(f);
        count++;
      } catch (e) {
        print("Failed to decrypt ${f.path}: $e");
      }
    }
    return count;
  }
}
