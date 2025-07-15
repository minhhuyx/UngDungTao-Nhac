import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:google_mobile_ads/google_mobile_ads.dart';

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
    final highlightColor = const Color(0xFFADD8E6);

    return Card(
      color: backgroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: highlightColor, width: 1.0),
      ),
      child: Column(
        children: [
          _buildListTile(
            Icons.language,
            'Ngôn Ngữ',
            textColor: textColor,
            iconColor: iconColor,
            trailing: Text(
              "Tiếng Việt",
              style: GoogleFonts.beVietnamPro(color: textColor),
            ),
          ),
          _buildListTile(
            Icons.star_border,
            'Đánh giá',
            textColor: textColor,
            iconColor: iconColor,
          ),
          _buildListTile(
            Icons.privacy_tip_outlined,
            'Chính sách bảo mật',
            textColor: textColor,
            iconColor: iconColor,
          ),
          _buildListTile(
            Icons.article_outlined,
            'Điều khoản sử dụng',
            textColor: textColor,
            iconColor: iconColor,
          ),
          _buildSwitchTile(
            Icons.notifications,
            'Thông Báo',
            notificationsEnabled,
            onNotificationsChanged,
            textColor,
            iconColor,
          ),
          _buildSwitchTile(
            Icons.dark_mode,
            'Giao diện',
            isDarkTheme,
            onDarkThemeChanged,
            textColor,
            iconColor,
          ),
          _buildActionTile(
            Icons.delete,
            'Bộ nhớ đệm',
            onClearCache,
            textColor,
            iconColor,
            arrowColor,
          ),
          _buildActionTile(
            Icons.edit,
            'Chỉnh sửa hồ sơ',
            onEditProfile,
            textColor,
            iconColor,
            arrowColor,
          ),
        ],
      ),
    );
  }

  Widget _buildListTile(
    IconData icon,
    String title, {
    required Color textColor,
    required Color iconColor,
    Widget? trailing,
  }) {
    return ListTile(
      leading: Icon(icon, color: iconColor),
      title: Text(title, style: GoogleFonts.beVietnamPro(color: textColor)),
      trailing:
          trailing ??
          Icon(
            Icons.arrow_forward_ios,
            color: iconColor.withOpacity(0.6),
            size: 16,
          ),
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
      title: Text(title, style: GoogleFonts.beVietnamPro(color: textColor)),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeTrackColor: Color(0xFFADD8E6),
        thumbColor: MaterialStateProperty.all(iconColor),
        inactiveTrackColor: Colors.grey[300],
      ),
    );
  }

  Widget _buildActionTile(
    IconData icon,
    String title,
    VoidCallback onTap,
    Color textColor,
    Color iconColor,
    Color arrowColor,
  ) {
    return ListTile(
      leading: Icon(icon, color: iconColor),
      title: Text(title, style: GoogleFonts.beVietnamPro(color: textColor)),
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

  late BannerAd _bannerAd;
  bool _isBannerAdReady = false;

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
    _settingsFuture = _loadSettings();

    _bannerAd = BannerAd(
      adUnitId: 'ca-app-pub-3940256099942544/6300978111', // banner test
      request: AdRequest(),
      size: AdSize.banner,
      listener: BannerAdListener(
        onAdLoaded: (_) => setState(() => _isBannerAdReady = true),
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
        },
      ),
    )..load();
  }

  @override
  void dispose() {
    _bannerAd.dispose();
    super.dispose();
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
        SnackBar(
          content: Text(
            'Lỗi khi tải cài đặt: $e',
            style: GoogleFonts.beVietnamPro(),
          ),
        ),
      );
    }
  }

  Future<void> _saveSettings() async {
    final user = _auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Vui lòng đăng nhập để lưu cài đặt',
            style: GoogleFonts.beVietnamPro(),
          ),
        ),
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
        SnackBar(
          content: Text(
            'Cài đặt đã được lưu thành công',
            style: GoogleFonts.beVietnamPro(),
          ),
        ),
      );
    } catch (e) {
      print('Error saving settings: $e');
      String errorMessage = 'Lỗi khi lưu cài đặt';
      if (e.toString().contains('permission-denied')) {
        errorMessage =
            'Không có quyền lưu cài đặt. Vui lòng kiểm tra cấu hình Firebase.';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage, style: GoogleFonts.beVietnamPro()),
        ),
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
          SnackBar(
            content: Text('Cache cleared!', style: GoogleFonts.beVietnamPro()),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'No cache found to clear',
              style: GoogleFonts.beVietnamPro(),
            ),
          ),
        );
      }
    } catch (e) {
      print('Error clearing cache: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Lỗi khi xóa cache: $e',
            style: GoogleFonts.beVietnamPro(),
          ),
        ),
      );
    }
  }

  Future<void> _logout() async {
    bool? confirm = await showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(
              'Xác nhận đăng xuất',
              style: GoogleFonts.beVietnamPro(),
            ),
            content: Text(
              'Bạn có chắc chắn muốn đăng xuất?',
              style: GoogleFonts.beVietnamPro(),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('Hủy', style: GoogleFonts.beVietnamPro()),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red, // màu nền của nút
                  foregroundColor: Colors.white, // màu chữ
                  shadowColor: Colors.redAccent, // màu bóng (nếu có)
                  elevation: 4, // độ nổi của nút
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10), // bo góc
                  ),
                ),
                child: Text(
                  'Đăng xuất',
                  style: GoogleFonts.beVietnamPro(fontSize: 16, fontWeight: FontWeight.w600),
                ),
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
        SnackBar(
          content: Text(
            'Đăng xuất thành công!',
            style: GoogleFonts.beVietnamPro(),
          ),
        ),
      );
    } catch (e) {
      print('Lỗi khi đăng xuất: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Lỗi khi đăng xuất: $e',
            style: GoogleFonts.beVietnamPro(),
          ),
        ),
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
      builder:
          (context) => AlertDialog(
            title: Text('Chỉnh sửa hồ sơ', style: GoogleFonts.beVietnamPro()),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: 'Tên người dùng',
                    labelStyle: GoogleFonts.beVietnamPro(
                      color: highlightColor, // 🔵 Màu cho label
                      fontWeight: FontWeight.w600,
                    ),
                    border: OutlineInputBorder(),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                        color: highlightColor, // Màu viền khi focus
                        width: 3.0,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                        color: Colors.grey, // Màu viền khi chưa focus
                        width: 1.0,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: currentPasswordController,
                  decoration: InputDecoration(
                    labelText: 'Mật khẩu hiện tại',
                    labelStyle: GoogleFonts.beVietnamPro(
                      color: highlightColor, // 🔵 Màu cho label
                      fontWeight: FontWeight.w600,
                    ),
                    border: OutlineInputBorder(),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                        color: highlightColor, // Màu viền khi focus
                        width: 3.0,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                        color: Colors.grey, // Màu viền khi chưa focus
                        width: 1.0,
                      ),
                    ),
                  ),
                  obscureText: true,
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: passwordController,
                  decoration: InputDecoration(
                    labelText: 'Mật khẩu mới (để trống nếu không cập nhật)',
                    labelStyle: GoogleFonts.beVietnamPro(
                      color: highlightColor, // 🔵 Màu cho label
                      fontWeight: FontWeight.w600,
                    ),
                    border: OutlineInputBorder(),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                        color: highlightColor, // Màu viền khi focus
                        width: 3.0,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                        color: Colors.grey, // Màu viền khi chưa focus
                        width: 1.0,
                      ),
                    ),
                  ),
                  obscureText: true,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Hủy', style: GoogleFonts.beVietnamPro()),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (passwordController.text.isNotEmpty &&
                      currentPasswordController.text.length < 6) {

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Mật khẩu hiện tại phải có ít nhất 6 ký tự',
                          style: GoogleFonts.beVietnamPro(),
                        ),
                      ),
                    );
                    return;
                  }

                  if (passwordController.text.isNotEmpty &&
                      passwordController.text.length < 6) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Mật khẩu mới phải có ít nhất 6 ký tự',
                          style: GoogleFonts.beVietnamPro(),
                        ),
                      ),
                    );
                    return;
                  }

                  if (currentPasswordController.text.isNotEmpty &&
                      passwordController.text.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Vui lòng nhập khẩu mới',
                          style: GoogleFonts.beVietnamPro(),
                        ),
                      ),
                    );
                    return;
                  }

                  try {
                    if (nameController.text.isNotEmpty &&
                        nameController.text != _currentUser?.displayName) {
                      await _currentUser?.updateDisplayName(
                        nameController.text,
                      );
                    }

                    if (passwordController.text.isNotEmpty) {
                      try {
                        final credential = EmailAuthProvider.credential(
                          email: _currentUser!.email!,
                          password: currentPasswordController.text,
                        );
                        await _currentUser!.reauthenticateWithCredential(
                          credential,
                        );
                        await _currentUser?.updatePassword(
                          passwordController.text,
                        );
                      } on FirebaseAuthException catch (e) {
                        Navigator.pop(context);
                        String errorMessage;
                        if (e.code == 'wrong-password') {
                          errorMessage = 'Mật khẩu hiện tại không đúng';
                        } else if (e.code == 'too-many-requests') {
                          errorMessage =
                              'Quá nhiều yêu cầu, vui lòng thử lại sau';
                        } else if (e.code == 'user-mismatch') {
                          errorMessage = 'Thông tin xác thực không khớp';
                        } else {
                          errorMessage = 'Lỗi xác thực';
                          print(
                            'FirebaseAuthException: code=${e.code}, message=${e.message}',
                          );
                        }
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              errorMessage,
                              style: GoogleFonts.beVietnamPro(),
                            ),
                          ),
                        );
                        return;
                      } catch (e) {
                        Navigator.pop(context);
                        print('Unexpected error during reauthentication: $e');
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Lỗi xác thực không xác định',
                              style: GoogleFonts.beVietnamPro(),
                            ),
                          ),
                        );
                        return;
                      }
                    }

                    await _currentUser?.reload();
                    _loadUserInfo();

                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Cập nhật hồ sơ thành công!',
                          style: GoogleFonts.beVietnamPro(),
                        ),
                      ),
                    );
                  } catch (e) {
                    Navigator.pop(context);
                    print('Lỗi khi cập nhật hồ sơ: $e');
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Lỗi khi cập nhật hồ sơ: $e',
                          style: GoogleFonts.beVietnamPro(),
                        ),
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: highlightColor, // màu nền của nút
                  foregroundColor: Colors.black, // màu chữ
                  shadowColor: highlightColor, // màu bóng (nếu có)
                  elevation: 4, // độ nổi của nút
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10), // bo góc
                  ),
                ),
                child: Text('Lưu', style: GoogleFonts.beVietnamPro()),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textColor =
        Theme.of(context).brightness == Brightness.dark
            ? Colors.white
            : Colors.black87;

    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;

    return FutureBuilder<void>(
      future: _settingsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            appBar: AppBar(
              title: Text('CÀI ĐẶT', style: GoogleFonts.beVietnamPro()),
              backgroundColor: highlightColor,
            ),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(
              title: Text('CÀI ĐẶT', style: GoogleFonts.beVietnamPro()),
              backgroundColor: highlightColor,
            ),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Lỗi khi tải cài đặt: ${snapshot.error}',
                    style: GoogleFonts.beVietnamPro(
                      color: Colors.red,
                      fontSize: 16,
                    ),
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
                    child: Text('Thử lại', style: GoogleFonts.beVietnamPro()),
                  ),
                ],
              ),
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: Text('CÀI ĐẶT', style: GoogleFonts.beVietnamPro()),
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
                    side: BorderSide(color: highlightColor, width: 1.5),
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
                              color:
                                  Theme.of(context).brightness ==
                                          Brightness.dark
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
                                style: GoogleFonts.beVietnamPro(
                                  fontSize: 16,
                                  color:
                                      Theme.of(context).brightness ==
                                              Brightness.dark
                                          ? Colors.white
                                          : Colors.black,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Email: ${_currentUser?.email ?? "N/A"}',
                                style: GoogleFonts.beVietnamPro(
                                  fontSize: 16,
                                  color:
                                      Theme.of(context).brightness ==
                                              Brightness.dark
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
                ),
                const SizedBox(height: 20),
                if (_isBannerAdReady)
                  Container(
                    height: _bannerAd.size.height.toDouble(),
                    width: _bannerAd.size.width.toDouble(),
                    child: AdWidget(ad: _bannerAd),
                  ),
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
          floatingActionButton:
              _isLoggedIn
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
