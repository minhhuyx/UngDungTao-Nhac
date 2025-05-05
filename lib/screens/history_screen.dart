import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class LyricsEntry {
  final String key;
  final String generatedLyrics;
  final String language;
  final String theme;
  final String tags;
  final DateTime date;

  LyricsEntry(this.key, this.generatedLyrics, this.language, this.theme,
      this.tags, this.date);
}

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({Key? key}) : super(key: key);

  @override
  _HistoryScreenState createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final DatabaseReference _databaseRef = FirebaseDatabase.instance.ref();

  // Lấy danh sách lịch sử lời bài hát từ Firebase
  Stream<List<LyricsEntry>> _getHistoryStream() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('Người dùng chưa đăng nhập.');
    }
    final userId = user.uid;
    return _databaseRef
        .child('lyrics_history/$userId')
        .orderByChild('created_at')
        .onValue
        .map((event) {
      final List<LyricsEntry> history = [];
      if (event.snapshot.exists) {
        final data = Map<String, dynamic>.from(event.snapshot.value as Map);
        data.forEach((key, value) {
          final entry = Map<String, dynamic>.from(value);
          final timestamp = entry['created_at'] ?? 0;
          print('Key: $key, Timestamp: $timestamp, Formatted: ${_formatDate(DateTime.fromMillisecondsSinceEpoch(timestamp))}');
          history.add(LyricsEntry(
            key,
            entry['generated_lyrics'] ?? '',
            entry['language'] ?? '',
            entry['theme'] ?? '',
            entry['tags'] ?? '',
            DateTime.fromMillisecondsSinceEpoch(timestamp),
          ));
        });
        history.sort((a, b) => b.date.compareTo(a.date));
      }
      return history;
    });
  }

  // Xóa một mục lời bài hát khỏi lịch sử
  Future<void> _deleteEntry(String key) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final userId = user.uid;
    try {
      // Xóa thông tin lời bài hát trên Realtime Database
      await _databaseRef.child('lyrics_history/$userId/$key').remove();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã xóa lời bài hát')),
      );
    } catch (e) {
      print('Lỗi khi xóa lời bài hát: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi khi xóa lời bài hát: $e')),
      );
    }
  }

  // Xóa toàn bộ lịch sử lời bài hát
  Future<void> _clearHistory() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final userId = user.uid;
    try {
      // Xóa dữ liệu trên Realtime Database
      await _databaseRef.child('lyrics_history/$userId').remove();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã xóa toàn bộ lịch sử lời bài hát')),
      );
    } catch (e) {
      print('Lỗi khi xóa lịch sử: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi khi xóa lịch sử: $e')),
      );
    }
  }

  // Hiển thị toàn bộ lời bài hát trong dialog với nút Copy ở góc trên cùng bên phải
  void _showLyricsDialog(LyricsEntry entry) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Song Lyrics'),
            IconButton(
              icon: const Icon(Icons.copy),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: entry.generatedLyrics));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Lyrics copied to clipboard!')),
                );
              },
              tooltip: 'Copy lyrics',
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Text(
            entry.generatedLyrics,
            style: const TextStyle(fontSize: 16),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return DateFormat('yyyy-MM-dd – kk:mm').format(date);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lyrics History'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: _clearHistory,
          ),
        ],
      ),
      body: StreamBuilder<List<LyricsEntry>>(
        stream: _getHistoryStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          final history = snapshot.data ?? [];
          if (history.isEmpty) {
            return const Center(child: Text('No lyrics generated yet!'));
          }
          return ListView.builder(
            itemCount: history.length,
            itemBuilder: (context, index) {
              final entry = history[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: ListTile(
                  onTap: () => _showLyricsDialog(entry),
                  title: const Text(
                    'Song Lyrics',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (entry.language.isNotEmpty)
                        Text('Language: ${entry.language}'),
                      if (entry.theme.isNotEmpty) Text('Theme: ${entry.theme}'),
                      if (entry.tags.isNotEmpty) Text('Tags: ${entry.tags}'),
                      Text('Date: ${_formatDate(entry.date)}'),
                    ],
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _deleteEntry(entry.key),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}