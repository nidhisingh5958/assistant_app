import 'package:flutter/material.dart';
import 'package:listen_iq/screens/components/appbar.dart';
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
  String _searchPath = '';

  @override
  void initState() {
    super.initState();
    _loadRecordings();
  }

  Future<void> _loadRecordings() async {
    setState(() {
      _isLoading = true;
    });

    try {
      List<FileSystemEntity> allFiles = [];

      // Search in multiple directories
      List<Directory?> searchDirectories = [];

      if (Platform.isAndroid) {
        // Common Android recording directories
        searchDirectories.addAll([
          Directory('/storage/emulated/0/Movies/ScreenRecordings'),
          Directory('/storage/emulated/0/DCIM/ScreenRecorder'),
          Directory('/storage/emulated/0/Movies'),
          Directory('/storage/emulated/0/Pictures/Screenshots'),
          Directory('/storage/emulated/0/Download'),
          await getExternalStorageDirectory(),
        ]);
      } else {
        searchDirectories.add(await getApplicationDocumentsDirectory());
      }

      for (Directory? dir in searchDirectories) {
        if (dir != null && await dir.exists()) {
          try {
            print('Searching in directory: ${dir.path}');

            // Get all entities first
            List<FileSystemEntity> entities = await dir
                .list(recursive: false)
                .toList();

            // Filter for files only (not directories) and check for video files
            List<FileSystemEntity> files = entities
                .where(
                  (entity) => entity is File,
                ) // Only files, not directories
                .where((file) {
                  String fileName = file.path.toLowerCase();
                  return fileName.endsWith('.mp4') ||
                      fileName.endsWith('.avi') ||
                      fileName.endsWith('.mov') ||
                      fileName.endsWith('.mkv') ||
                      fileName.contains('screen') ||
                      fileName.contains('record');
                })
                .toList();

            print('Found ${files.length} potential recordings in ${dir.path}');
            allFiles.addAll(files);

            if (_searchPath.isEmpty && files.isNotEmpty) {
              _searchPath = dir.path;
            }
          } catch (e) {
            print('Error reading directory ${dir.path}: $e');
          }
        }
      }

      // Remove duplicates based on file path
      Map<String, FileSystemEntity> uniqueFiles = {};
      for (FileSystemEntity file in allFiles) {
        uniqueFiles[file.path] = file;
      }

      List<FileSystemEntity> finalFiles = uniqueFiles.values.toList();

      // Sort by modification date (newest first) - with error handling
      finalFiles.sort((a, b) {
        try {
          return File(
            b.path,
          ).lastModifiedSync().compareTo(File(a.path).lastModifiedSync());
        } catch (e) {
          print(
            'Error getting modification time for ${a.path} or ${b.path}: $e',
          );
          return 0; // Keep original order if we can't get modification times
        }
      });

      print('Total unique recordings found: ${finalFiles.length}');

      setState(() {
        _recordings = finalFiles;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading recordings: $e');
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load recordings: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
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
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete recording: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showDeleteConfirmation(String path, String fileName) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Color(0xFF1E1E1E),
          title: Text(
            'Delete Recording',
            style: TextStyle(color: Colors.white),
          ),
          content: Text(
            'Are you sure you want to delete "$fileName"?',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel', style: TextStyle(color: Colors.grey)),
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
      appBar: AppHeader(
        title: 'Screen Recordings',
        isInChat: true,
        onBackPressed: () => Navigator.pop(context),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadRecordings,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: Colors.blue))
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
                  if (_searchPath.isNotEmpty) ...[
                    SizedBox(height: 16),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 32),
                      child: Text(
                        'Searched in: $_searchPath',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadRecordings,
              color: Colors.blue,
              child: ListView.builder(
                padding: EdgeInsets.all(16),
                itemCount: _recordings.length,
                itemBuilder: (context, index) {
                  File file = File(_recordings[index].path);
                  String fileName = file.path.split('/').last;

                  // Safe handling of file properties
                  DateTime modifiedDate;
                  int fileSize;

                  try {
                    modifiedDate = file.lastModifiedSync();
                    fileSize = file.lengthSync();
                  } catch (e) {
                    print('Error getting file stats for ${file.path}: $e');
                    modifiedDate = DateTime.now();
                    fileSize = 0;
                  }

                  return Card(
                    elevation: 4,
                    margin: EdgeInsets.only(bottom: 12),
                    color: Color(0xFF1E1E1E),
                    child: ListTile(
                      contentPadding: EdgeInsets.all(16),
                      leading: Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.play_circle_filled,
                          color: Colors.blue,
                          size: 30,
                        ),
                      ),
                      title: Text(
                        fileName,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                          color: Colors.white,
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
                              color: Colors.grey.shade400,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            'Size: ${_formatFileSize(fileSize)}',
                            style: TextStyle(
                              color: Colors.grey.shade400,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      trailing: PopupMenuButton(
                        color: Color(0xFF2E2E2E),
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            value: 'play',
                            child: Row(
                              children: [
                                Icon(
                                  Icons.play_arrow,
                                  size: 20,
                                  color: Colors.white,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Play',
                                  style: TextStyle(color: Colors.white),
                                ),
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
