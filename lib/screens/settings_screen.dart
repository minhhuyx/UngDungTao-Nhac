import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _audioQuality = 'Medium';
  final List<String> _qualityOptions = ['Low', 'Medium', 'High'];
  bool _notificationsEnabled = true;
  bool _isDarkTheme = false;
  String? _errorMessage;

  final DatabaseReference _databaseRef = FirebaseDatabase.instance.ref();
  final highlightColor = const Color(0xFFFFC0CB); // Đồng nhất với HomeScreen

  // Hàm tải cài đặt từ Firebase
  Future<void> _loadSettings() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print('No user logged in');
      throw Exception('Vui lòng đăng nhập để tải cài đặt');
    }

    final userId = user.uid;
    try {
      final snapshot = await _databaseRef.child('settings/$userId').get();
      if (snapshot.exists) {
        final data = Map<String, dynamic>.from(snapshot.value as Map);
        _audioQuality = data['audio_quality'] ?? 'Medium';
        _notificationsEnabled = data['notifications_enabled'] ?? true;
        _isDarkTheme = data['is_dark_theme'] ?? false;
      }
    } catch (e) {
      print('Error loading settings: $e');
      throw Exception('Lỗi khi tải cài đặt: $e');
    }
  }

  // Lưu cài đặt vào Firebase
  Future<void> _saveSettings() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print('No user logged in');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng đăng nhập để lưu cài đặt')),
      );
      return;
    }

    final userId = user.uid;
    try {
      print('Saving settings for user: $userId');
      await _databaseRef.child('settings/$userId').set({
        'audio_quality': _audioQuality,
        'notifications_enabled': _notificationsEnabled,
        'is_dark_theme': _isDarkTheme,
      });
      print('Settings saved successfully');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cài đặt đã được lưu thành công')),
      );
    } catch (e) {
      print('Error saving settings: $e');
      String errorMessage = 'Lỗi khi lưu cài đặt';
      if (e.toString().contains('permission-denied')) {
        errorMessage = 'Không có quyền lưu cài đặt. Vui lòng kiểm tra cấu hình Firebase.';
        setState(() {
          _isDarkTheme = !_isDarkTheme;
        });
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage)),
      );
    }
  }

  // Xóa cache (xóa file MP3 đã tải về cục bộ)
  Future<void> _clearCache() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final cacheDir = Directory('${directory.path}/history_songs');
      if (await cacheDir.exists()) {
        await cacheDir.delete(recursive: true);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cache cleared!')),
      );
    } catch (e) {
      print('Error clearing cache: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi khi xóa cache: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _loadSettings(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            appBar: AppBar(title: const Text('Settings')),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(title: const Text('Settings')),
            body: Center(child: Text('Lỗi: ${snapshot.error}')),
          );
        }

        // Xác định màu chữ dựa trên theme
        final textColor = Theme.of(context).brightness == Brightness.dark
            ? Colors.white
            : Colors.black87;

        return Scaffold(
          appBar: AppBar(title: const Text('Settings')),
          body: Padding(
            padding: const EdgeInsets.all(16.0),
            child: ListView(
              children: [
                const Text(
                  'Audio Quality',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                DropdownButton<String>(
                  value: _audioQuality,
                  onChanged: (value) {
                    setState(() {
                      _audioQuality = value!;
                    });
                    _saveSettings();
                  },
                  items: _qualityOptions
                      .map((quality) => DropdownMenuItem(
                    value: quality,
                    child: Text(quality),
                  ))
                      .toList(),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Enable Notifications',
                      style: TextStyle(
                        fontSize: 18,
                        color: textColor,
                      ),
                    ),
                    Switch(
                      value: _notificationsEnabled,
                      onChanged: (value) {
                        setState(() {
                          _notificationsEnabled = value;
                        });
                        _saveSettings();
                      },
                      activeTrackColor: highlightColor,
                      thumbColor: MaterialStateProperty.all(Colors.black87),
                      inactiveTrackColor: Colors.grey[300],
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Dark Theme',
                      style: TextStyle(
                        fontSize: 18,
                        color: textColor,
                      ),
                    ),
                    Switch(
                      value: _isDarkTheme,
                      onChanged: (value) {
                        setState(() {
                          _isDarkTheme = value;
                        });
                        _saveSettings();
                      },
                      activeTrackColor: highlightColor,
                      thumbColor: MaterialStateProperty.all(Colors.black87),
                      inactiveTrackColor: Colors.grey[300],
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _clearCache,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: highlightColor,
                    foregroundColor: Colors.black87,
                    shape: RoundedRectangleBorder(
                      side: const BorderSide(
                        color: Colors.black87,
                        width: 1.0,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Clear Cache',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (_errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 20),
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: Colors.red, fontSize: 16),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}