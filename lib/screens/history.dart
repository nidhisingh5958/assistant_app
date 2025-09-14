import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:listen_iq/screens/components/appbar.dart';
import 'package:listen_iq/utilities/router_constants.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final ChatHistoryManager _historyManager = ChatHistoryManager();
  Map<String, List<String>> _organizedHistory = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() {
      _isLoading = true;
    });

    // Simulate loading delay (remove this in production)
    await Future.delayed(const Duration(milliseconds: 500));

    final history = _historyManager.getOrganizedHistory();
    setState(() {
      _organizedHistory = history;
      _isLoading = false;
    });
  }

  bool get _hasAnyHistory {
    return _organizedHistory.values.any((list) => list.isNotEmpty);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppHeader(
        title: 'Chat History',
        isInChat: false,
        onBackPressed: () => Navigator.pop(context),
        onMenuPressed: () => Navigator.pop(context),
      ),
      body: SafeArea(
        child: _isLoading
            ? _buildLoadingState()
            : _hasAnyHistory
            ? _buildHistoryContent()
            : _buildNoHistoryState(),
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(child: CircularProgressIndicator());
  }

  Widget _buildHistoryContent() {
    return RefreshIndicator(
      onRefresh: _loadHistory,
      child: ListView(
        children: [
          ..._organizedHistory.entries
              .where((entry) => entry.value.isNotEmpty)
              .map((entry) {
                return HistorySection(
                  title: entry.key,
                  items: entry.value,
                  onItemDeleted: (item) => _deleteHistoryItem(entry.key, item),
                );
              }),
        ],
      ),
    );
  }

  Widget _buildNoHistoryState() {
    return RefreshIndicator(
      onRefresh: _loadHistory,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Container(
          height: MediaQuery.of(context).size.height - 200,
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.primaryContainer.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(50),
                ),
                child: Icon(
                  Icons.chat_bubble_outline,
                  size: 64,
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.7),
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'No Chat History',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Your conversation history will appear here once you start chatting with the AI assistant.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    context.goNamed(RouteConstants.chatHome);
                  },
                  icon: const Icon(Icons.chat),
                  label: const Text('Start New Chat'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: _loadHistory,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.refresh,
                      size: 18,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Refresh',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _deleteHistoryItem(String section, String item) {
    setState(() {
      _organizedHistory[section]?.remove(item);
    });
    _historyManager.deleteHistoryEntry(section, item);

    // Show snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('History item deleted'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () {
            // Implement undo functionality
            setState(() {
              _organizedHistory[section]?.add(item);
            });
          },
        ),
      ),
    );
  }
}

class HistorySection extends StatelessWidget {
  final String title;
  final List<String> items;
  final Function(String)? onItemDeleted;

  const HistorySection({
    required this.title,
    required this.items,
    this.onItemDeleted,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const Spacer(),
              Text(
                '${items.length} ${items.length == 1 ? 'item' : 'items'}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        ...items.map(
          (text) => HistoryItem(
            text: text,
            onDeleted: () => onItemDeleted?.call(text),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

class HistoryItem extends StatelessWidget {
  final String text;
  final VoidCallback? onDeleted;

  const HistoryItem({required this.text, this.onDeleted, super.key});

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key(text),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDeleted?.call(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        color: Theme.of(context).colorScheme.errorContainer,
        child: Icon(
          Icons.delete_outline,
          color: Theme.of(context).colorScheme.onErrorContainer,
        ),
      ),
      child: InkWell(
        onTap: () {
          // Navigate to chat bot screen with the selected query
          context.push(RouteConstants.chat, extra: text);
        },
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.primaryContainer.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  Icons.chat_outlined,
                  size: 16,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  text,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              Icon(
                Icons.chevron_right,
                size: 20,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Enhanced ChatHistoryManager with persistence and better data management
class ChatHistoryManager {
  static final ChatHistoryManager _instance = ChatHistoryManager._internal();

  factory ChatHistoryManager() {
    return _instance;
  }

  ChatHistoryManager._internal();

  // Private storage for history data
  Map<String, List<String>> _historyData = {};

  // Initialize with sample data or load from persistent storage
  Map<String, List<String>> getOrganizedHistory() {
    // In a real app, this would load from SharedPreferences or a database
    if (_historyData.isEmpty) {
      // Load sample data - replace with actual persistence logic
      _historyData = _loadSampleData();
    }
    return Map.from(_historyData);
  }

  // Load sample data (replace with actual data loading)
  Map<String, List<String>> _loadSampleData() {
    // Return empty data to demonstrate "no history" state
    // Change this to return sample data for testing:
    /*
    return {
      'Today': ["Can you summarise Vishal's timeline"],
      'Previous 30 days': [
        "Highlight the main points of Rashmi's report",
        "Analyze this prescription and give the dosage",
        "Message Laxmi that she can be hospitalized tomorrow",
      ],
      'Older': [
        "summarise Gautum's prescription",
        "What is helirab-d used for?",
        "What are the symptoms of malaria?",
        "What is the dosage of paracetamol?",
      ],
    };
    */
    return {'Today': [], 'Previous 30 days': [], 'Older': []};
  }

  // Add a new history entry
  void addHistoryEntry(String query) {
    final today = DateTime.now();
    final todayKey = 'Today';

    _historyData[todayKey] ??= [];
    _historyData[todayKey]!.insert(0, query);

    // In a real app, save to persistent storage here
    _saveToPersistentStorage();
  }

  // Delete a history entry
  void deleteHistoryEntry(String section, String item) {
    _historyData[section]?.remove(item);
    _saveToPersistentStorage();
  }

  // Clear all history
  void clearAllHistory() {
    _historyData.clear();
    _saveToPersistentStorage();
  }

  // Save to persistent storage (implement with SharedPreferences or SQLite)
  void _saveToPersistentStorage() {
    // Implement actual persistence here
    // Example with SharedPreferences:
    // final prefs = await SharedPreferences.getInstance();
    // await prefs.setString('chat_history', json.encode(_historyData));
  }

  // Load from persistent storage
  void _loadFromPersistentStorage() {
    // Implement actual loading here
    // Example with SharedPreferences:
    // final prefs = await SharedPreferences.getInstance();
    // final historyJson = prefs.getString('chat_history');
    // if (historyJson != null) {
    //   _historyData = Map<String, List<String>>.from(json.decode(historyJson));
    // }
  }
}
