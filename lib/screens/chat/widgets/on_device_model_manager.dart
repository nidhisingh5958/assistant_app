import 'package:flutter/foundation.dart';
import 'package:listen_iq/services/file/embeddings.dart';
import 'package:listen_iq/services/file/vector_store.dart';
import 'package:listen_iq/screens/chat/answerUser.dart';

/// Manages on-device TensorFlow Lite model lifecycle and performance
class OnDeviceModelManager {
  static OnDeviceModelManager? _instance;
  static OnDeviceModelManager get instance => _instance ??= OnDeviceModelManager._();
  OnDeviceModelManager._();

  // Model state
  bool _isInitialized = false;
  bool _isInitializing = false;
  String _status = "Not initialized";
  DateTime? _lastUsed;

  // Performance tracking
  int _inferenceCount = 0;
  List<int> _responseTimes = [];
  static const int _maxResponseTimeHistory = 10;

  // Getters
  bool get isReady => _isInitialized && _isModelLoaded;
  String get status => _status;
  bool get isInitializing => _isInitializing;
  double get averageResponseTime {
    if (_responseTimes.isEmpty) return 0;
    return _responseTimes.reduce((a, b) => a + b) / _responseTimes.length;
  }

  /// Initialize the on-device model
  Future<bool> initialize() async {
    if (_isInitialized || _isInitializing) return _isInitialized;

    _isInitializing = true;
    _status = "Initializing DistilGPT-2...";

    try {
      debugPrint("🚀 Starting on-device model initialization");
      
      // Load TensorFlow Lite model
      await _loadModel();
      
      if (_isModelLoaded) {
        _isInitialized = true;
        _status = "Ready • On-device processing";
        debugPrint("✅ On-device DistilGPT-2 model loaded successfully");
        
        // Test inference to ensure everything works
        await _testInference();
        
        return true;
      } else {
        throw Exception("Model failed to load");
      }
    } catch (e) {
      _status = "Initialization failed: ${e.toString().split(':').last}";
      debugPrint("❌ Model initialization failed: $e");
      return false;
    } finally {
      _isInitializing = false;
    }
  }

  /// Test inference to validate model functionality
  Future<void> _testInference() async {
    try {
      debugPrint("🧪 Testing model inference...");
      final testPrompt = "Test prompt for validation:";
      await generateAnswer(testPrompt, maxGenLen: 5);
      debugPrint("✅ Model inference test passed");
    } catch (e) {
      debugPrint("⚠️ Model inference test failed: $e");
      throw Exception("Model inference validation failed");
    }
  }

  /// Process a query using the on-device RAG pipeline
  Future<String> processQuery(String query, {
    int maxGenLength = 50,
    double temperature = 0.7,
  }) async {
    if (!isReady) {
      return "On-device model is not ready. Please wait for initialization.";
    }

    final stopwatch = Stopwatch()..start();
    _lastUsed = DateTime.now();
    _inferenceCount++;

    try {
      _status = "Processing query locally...";
      
      // Step 1: Load embeddings
      final embeddings = await Embeddings.load();
      
      // Step 2: Validate model compatibility
      if (!await embeddings.validateModel()) {
        throw Exception("Model validation failed");
      }

      // Step 3: Vector search
      _status = "Searching knowledge base...";
      final store = await VectorStore.open(embedSize: 384);
      final queryVec = embeddings.embedTexts([query])[0];
      final results = await store.search(queryVec, topK: 2);
      await store.close();

      if (results.isEmpty) {
        _status = "Ready • On-device processing";
        return "I couldn't find relevant information for your question in my local knowledge base.";
      }

      // Step 4: Prepare context
      final context = _prepareContext(results);
      if (