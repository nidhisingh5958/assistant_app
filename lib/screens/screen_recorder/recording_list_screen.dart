import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'video_player_screen.dart';

class RecordingsListScreen extends StatefulWidget {
  @override
  _RecordingsListScreenState createState() => _RecordingsListScreenState();
}

class _RecordingsListScreenState extends State<RecordingsListScreen> {
  List<FileSystemEntity> _recordings = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRecordings();
  }

  Future<void> _loadRecordings() async {
    try {
      Directory? directory;
      if (Platform.isAndroid) {
        directory = await getExternalStorageDirectory();
      } else {
        directory = await getApplicationDocumentsDirectory();
      }

      if (directory != null) {
        List<FileSystemEntity> files = directory
            .listSync()
            .where((file) => file.path.endsWith('.mp4'))
            .toList();

        // Sort by modification date (newest first)
        files.sort(
          (a, b) => File(
            b.path,
          ).lastModifiedSync().compareTo(File(a.path).lastModifiedSync()),
        );

        setState(() {
          _recordings = files;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load recordings: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String _formatDate(DateTime date) {
    return DateFormat('MMM dd, yyyy - HH:mm').format(date);
  }

  Future<void> _deleteRecording(String path) async {
    try {
      await File(path).delete();
      _loadRecordings();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Recording deleted successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete recording: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showDeleteConfirmation(String path, String fileName) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Delete Recording'),
          content: Text('Are you sure you want to delete "$fileName"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _deleteRecording(path);
              },
              child: Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Screen Recordings'),
        backgroundColor: Colors.blue.shade700,
        elevation: 0,
        actions: [
          IconButton(icon: Icon(Icons.refresh), onPressed: _loadRecordings),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _recordings.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.video_library_outlined,
                    size: 80,
                    color: Colors.grey,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'No recordings found',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Start recording to see your videos here',
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadRecordings,
              child: ListView.builder(
                padding: EdgeInsets.all(16),
                itemCount: _recordings.length,
                itemBuilder: (context, index) {
                  File file = File(_recordings[index].path);
                  String fileName = file.path.split('/').last;
                  DateTime modifiedDate = file.lastModifiedSync();
                  int fileSize = file.lengthSync();

                  return Card(
                    elevation: 4,
                    margin: EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      contentPadding: EdgeInsets.all(16),
                      leading: Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: Colors.blue.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.play_circle_filled,
                          color: Colors.blue.shade700,
                          size: 30,
                        ),
                      ),
                      title: Text(
                        fileName,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(height: 4),
                          Text(
                            _formatDate(modifiedDate),
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            'Size: ${_formatFileSize(fileSize)}',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      trailing: PopupMenuButton(
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            value: 'play',
                            child: Row(
                              children: [
                                Icon(Icons.play_arrow, size: 20),
                                SizedBox(width: 8),
                                Text('Play'),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete, size: 20, color: Colors.red),
                                SizedBox(width: 8),
                                Text(
                                  'Delete',
                                  style: TextStyle(color: Colors.red),
                                ),
                              ],
                            ),
                          ),
                        ],
                        onSelected: (value) {
                          if (value == 'play') {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => VideoPlayerScreen(
                                  videoPath: file.path,
                                  videoTitle: fileName,
                                ),
                              ),
                            );
                          } else if (value == 'delete') {
                            _showDeleteConfirmation(file.path, fileName);
                          }
                        },
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => VideoPlayerScreen(
                              videoPath: file.path,
                              videoTitle: fileName,
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
    );
  }
}
