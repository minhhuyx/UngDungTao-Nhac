import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class SettingsCard extends StatelessWidget {
  final String audioQuality;
  final List<String> qualityOptions;
  final bool notificationsEnabled;
  final bool isDarkTheme;
  final VoidCallback onClearCache;
  final VoidCallback onEditProfile;
  final ValueChanged<bool> onNotificationsChanged;
  final ValueChanged<bool> onDarkThemeChanged;

  const SettingsCard({
    super.key,
    required this.audioQuality,
    required this.qualityOptions,
    required this.notificationsEnabled,
    required this.isDarkTheme,
    required this.onClearCache,
    required this.onEditProfile,
    required this.onNotificationsChanged,
    required this.onDarkThemeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? Colors.black54 : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    final iconColor = textColor;
    final arrowColor = isDark ? Colors.white54 : Colors.black54;
    final highlightColor = const Color(0xFFADD8E6); // Định nghĩa highlightColor

    return Card(
      color: backgroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: highlightColor, width: 1.0), // Thêm viền
      ),
      child: Column(
        children: [
          _buildListTile(Icons.language, 'Language',
              textColor: textColor,
              iconColor: iconColor,
              trailing: Text("English", style: TextStyle(color: textColor))),
          _buildListTile(Icons.star_border, 'Rate Us', textColor: textColor, iconColor: iconColor),
          _buildListTile(Icons.privacy_tip_outlined, 'Privacy Policy', textColor: textColor, iconColor: iconColor),
          _buildListTile(Icons.article_outlined, 'Terms of Use', textColor: textColor, iconColor: iconColor),
          _buildSwitchTile(
            Icons.notifications,
            'Enable Notifications',
            notificationsEnabled,
            onNotificationsChanged,
            textColor,
            iconColor,
          ),
          _buildSwitchTile(
            Icons.dark_mode,
            'Dark Theme',
            isDarkTheme,
            onDarkThemeChanged,
            textColor,
            iconColor,
          ),
          _buildActionTile(Icons.delete, 'Clear Cache', onClearCache, textColor, iconColor, arrowColor),
          _buildActionTile(Icons.edit, 'Chỉnh sửa hồ sơ', onEditProfile, textColor, iconColor, arrowColor),
        ],
      ),
    );
  }

  Widget _buildListTile(IconData icon, String title,
      {required Color textColor, required Color iconColor, Widget? trailing}) {
    return ListTile(
      leading: Icon(icon, color: iconColor),
      title: Text(title, style: TextStyle(color: textColor)),
      trailing: trailing ??
          Icon(Icons.arrow_forward_ios, color: iconColor.withOpacity(0.6), size: 16),
      onTap: () {
        // Handle navigation or logic here
      },
    );
  }

  Widget _buildSwitchTile(
      IconData icon,
      String title,
      bool value,
      ValueChanged<bool> onChanged,
      Color textColor,
      Color iconColor,
      ) {
    return ListTile(
      leading: Icon(icon, color: iconColor),
      title: Text(title, style: TextStyle(color: textColor)),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeTrackColor: Colors.lightBlueAccent,
        thumbColor: MaterialStateProperty.all(iconColor),
        inactiveTrackColor: Colors.grey[300],
      ),
    );
  }

  Widget _buildActionTile(IconData icon, String title, VoidCallback onTap,
      Color textColor, Color iconColor, Color arrowColor) {
    return ListTile(
      leading: Icon(icon, color: iconColor),
      title: Text(title, style: TextStyle(color: textColor)),
      trailing: Icon(Icons.arrow_forward_ios, color: arrowColor, size: 16),
      onTap: onTap,
    );
  }
}

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
  late Future<void> _settingsFuture;

  final _auth = FirebaseAuth.instance;
  User? _currentUser;
  bool _isLoggedIn = false;

  final DatabaseReference _databaseRef = FirebaseDatabase.instance.ref();
  final highlightColor = const Color(0xFFADD8E6);

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
    _settingsFuture = _loadSettings();
  }

  void _loadUserInfo() {
    setState(() {
      _currentUser = _auth.currentUser;
      _isLoggedIn = _currentUser != null;
    });
  }

  Future<void> _loadSettings() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        setState(() {
          _audioQuality = 'Medium';
          _notificationsEnabled = true;
          _isDarkTheme = false;
        });
        return;
      }

      final userId = user.uid;
      final snapshot = await _databaseRef.child('settings/$userId').get();
      if (snapshot.exists) {
        final data = Map<String, dynamic>.from(snapshot.value as Map);
        setState(() {
          _audioQuality = data['audio_quality'] ?? 'Medium';
          _notificationsEnabled = data['notifications_enabled'] ?? true;
          _isDarkTheme = data['is_dark_theme'] ?? false;
        });
      } else {
        setState(() {
          _audioQuality = 'Medium';
          _notificationsEnabled = true;
          _isDarkTheme = false;
        });
      }
    } catch (e) {
      print('Error loading settings: $e');
      setState(() {
        _audioQuality = 'Medium';
        _notificationsEnabled = true;
        _isDarkTheme = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi khi tải cài đặt: $e')),
      );
    }
  }

  Future<void> _saveSettings() async {
    final user = _auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng đăng nhập để lưu cài đặt')),
      );
      return;
    }

    final userId = user.uid;
    try {
      await _databaseRef.child('settings/$userId').set({
        'audio_quality': _audioQuality,
        'notifications_enabled': _notificationsEnabled,
        'is_dark_theme': _isDarkTheme,
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cài đặt đã được lưu thành công')),
      );
    } catch (e) {
      print('Error saving settings: $e');
      String errorMessage = 'Lỗi khi lưu cài đặt';
      if (e.toString().contains('permission-denied')) {
        errorMessage =
        'Không có quyền lưu cài đặt. Vui lòng kiểm tra cấu hình Firebase.';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage)),
      );
    }
  }

  Future<void> _clearCache() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final cacheDir = Directory('${directory.path}/history_songs');
      if (await cacheDir.exists()) {
        await cacheDir.delete(recursive: true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cache cleared!')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No cache found to clear')),
        );
      }
    } catch (e) {
      print('Error clearing cache: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi khi xóa cache: $e')),
      );
    }
  }

  Future<void> _logout() async {
    bool? confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận đăng xuất'),
        content: const Text('Bạn có chắc chắn muốn đăng xuất?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Đăng xuất'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _auth.signOut();
      setState(() {
        _isLoggedIn = false;
        _currentUser = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đăng xuất thành công!')),
      );
    } catch (e) {
      print('Lỗi khi đăng xuất: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi khi đăng xuất: $e')),
      );
    }
  }

  Future<void> _editProfile() async {
    final TextEditingController nameController = TextEditingController(
      text: _currentUser?.displayName ?? '',
    );
    final TextEditingController passwordController = TextEditingController();
    final TextEditingController currentPasswordController =
    TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Chỉnh sửa hồ sơ'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Tên hiển thị',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: currentPasswordController,
              decoration: const InputDecoration(
                labelText: 'Mật khẩu hiện tại',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 10),
            TextField(
              controller: passwordController,
              decoration: const InputDecoration(
                labelText: 'Mật khẩu mới (để trống nếu không thay đổi)',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () async {
              // Validate current password length if new password is provided
              if (passwordController.text.isNotEmpty &&
                  currentPasswordController.text.length < 6) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Mật khẩu hiện tại phải có ít nhất 6 ký tự'),
                  ),
                );
                return;
              }

              // Validate new password length if provided
              if (passwordController.text.isNotEmpty &&
                  passwordController.text.length < 6) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Mật khẩu mới phải có ít nhất 6 ký tự'),
                  ),
                );
                return;
              }

              try {
                // Update display name if changed
                if (nameController.text.isNotEmpty &&
                    nameController.text != _currentUser?.displayName) {
                  await _currentUser?.updateDisplayName(nameController.text);
                }

                // Update password if provided
                if (passwordController.text.isNotEmpty) {
                  try {
                    final credential = EmailAuthProvider.credential(
                      email: _currentUser!.email!,
                      password: currentPasswordController.text,
                    );
                    await _currentUser!.reauthenticateWithCredential(credential);
                    await _currentUser?.updatePassword(passwordController.text);
                  } on FirebaseAuthException catch (e) {
                    Navigator.pop(context);
                    String errorMessage;
                    if (e.code == 'wrong-password') {
                      errorMessage = 'Mật khẩu hiện tại không đúng';
                    } else if (e.code == 'too-many-requests') {
                      errorMessage = 'Quá nhiều yêu cầu, vui lòng thử lại sau';
                    } else if (e.code == 'user-mismatch') {
                      errorMessage = 'Thông tin xác thực không khớp';
                    } else {
                      errorMessage = 'Lỗi xác thực';
                      print('FirebaseAuthException: code=${e.code}, message=${e.message}');
                    }
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(errorMessage)),
                    );
                    return;
                  } catch (e) {
                    Navigator.pop(context);
                    print('Unexpected error during reauthentication: $e');
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Lỗi xác thực không xác định')),
                    );
                    return;
                  }
                }

                await _currentUser?.reload();
                _loadUserInfo();

                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Cập nhật hồ sơ thành công!')),
                );
              } catch (e) {
                Navigator.pop(context);
                print('Lỗi khi cập nhật hồ sơ: $e');
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Lỗi khi cập nhật hồ sơ: $e')),
                );
              }
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).brightness == Brightness.dark
        ? Colors.white
        : Colors.black87;

    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;

    return FutureBuilder<void>(
      future: _settingsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Cài đặt'),
              backgroundColor: highlightColor,
            ),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Cài đặt'),
              backgroundColor: highlightColor,
            ),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Lỗi khi tải cài đặt: ${snapshot.error}',
                    style: const TextStyle(color: Colors.red, fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _settingsFuture = _loadSettings();
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: highlightColor,
                      foregroundColor: Colors.black87,
                    ),
                    child: const Text('Thử lại'),
                  ),
                ],
              ),
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('My App'),
            backgroundColor: highlightColor,
            actions: [
              Builder(
                builder: (context) {
                  final double appBarHeight = AppBar().preferredSize.height;
                  final double imageHeight = appBarHeight * 10.0;

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: Image.asset(
                      'assets/logo.png',
                      height: imageHeight,
                      fit: BoxFit.contain,
                    ),
                  );
                },
              ),
            ],
          ),
          body: Padding(
            padding: const EdgeInsets.all(16.0),
            child: ListView(
              children: [
                const SizedBox(height: 20),
                Card(
                  color: isDarkTheme ? Colors.black : Colors.white,
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: highlightColor, width: 1.5), // Viền
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: Theme.of(context).brightness == Brightness.dark
                                  ? Colors.white54
                                  : Colors.black,
                              width: 1,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            image: const DecorationImage(
                              image: AssetImage('assets/avatar.jpg'),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Tên người dùng: ${_currentUser?.displayName ?? "Guest"}',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Theme.of(context).brightness == Brightness.dark
                                      ? Colors.white
                                      : Colors.black,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Email: ${_currentUser?.email ?? "N/A"}',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Theme.of(context).brightness == Brightness.dark
                                      ? Colors.white
                                      : Colors.black,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                ,
                const SizedBox(height: 20),
                SettingsCard(
                  audioQuality: _audioQuality,
                  qualityOptions: _qualityOptions,
                  notificationsEnabled: _notificationsEnabled,
                  isDarkTheme: _isDarkTheme,
                  onClearCache: _clearCache,
                  onEditProfile: _editProfile,
                  onNotificationsChanged: (value) {
                    setState(() {
                      _notificationsEnabled = value;
                    });
                    _saveSettings();
                  },
                  onDarkThemeChanged: (value) {
                    setState(() {
                      _isDarkTheme = value;
                    });
                    _saveSettings();
                  },
                ),
              ],
            ),
          ),
          floatingActionButton: _isLoggedIn
              ? FloatingActionButton(
            onPressed: _logout,
            backgroundColor: highlightColor,
            foregroundColor: Colors.black87,
            child: const Icon(Icons.logout),
          )
              : null,
        );
      },
    );
  }
}