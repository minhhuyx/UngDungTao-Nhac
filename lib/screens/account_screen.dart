import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({Key? key}) : super(key: key);

  @override
  _AccountScreenState createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  final _auth = FirebaseAuth.instance;
  User? _currentUser;
  bool _isLoggedIn = false;

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  // Tải thông tin người dùng từ Firebase
  void _loadUserInfo() {
    setState(() {
      _currentUser = _auth.currentUser;
      _isLoggedIn = _currentUser != null;
    });
  }

  // Hàm đăng xuất
  Future<void> _logout() async {
    try {
      await _auth.signOut();
      setState(() {
        _isLoggedIn = false;
        _currentUser = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đăng xuất thành công!')),
      );
      // Loại bỏ Navigator.pushReplacement, để StreamBuilder trong main.dart xử lý
    } catch (e) {
      print('Lỗi khi đăng xuất: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi khi đăng xuất: $e')),
      );
    }
  }

  // Hàm chỉnh sửa hồ sơ
  Future<void> _editProfile() async {
    final TextEditingController nameController =
    TextEditingController(text: _currentUser?.displayName ?? '');
    final TextEditingController passwordController = TextEditingController();

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
              try {
                // Cập nhật tên hiển thị
                if (nameController.text.isNotEmpty &&
                    nameController.text != _currentUser?.displayName) {
                  await _currentUser?.updateDisplayName(nameController.text);
                }

                // Cập nhật mật khẩu
                if (passwordController.text.isNotEmpty) {
                  if (passwordController.text.length < 6) {
                    throw Exception('Mật khẩu phải có ít nhất 6 ký tự.');
                  }
                  await _currentUser?.updatePassword(passwordController.text);
                }

                // Làm mới thông tin người dùng
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tài khoản'),
        backgroundColor: const Color(0xFFFFC0CB),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Thông tin tài khoản',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tên người dùng: ${_currentUser?.displayName ?? "Guest"}',
                      style: const TextStyle(fontSize: 18),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Email: ${_currentUser?.email ?? "N/A"}',
                      style: const TextStyle(fontSize: 18),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _editProfile,
                style: ElevatedButton.styleFrom(
                  side: const BorderSide(color: Colors.black87, width: 1.0),
                  backgroundColor: const Color(0xFFFFC0CB),
                  foregroundColor: Colors.black87,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Chỉnh sửa hồ sơ'),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _logout,
                style: ElevatedButton.styleFrom(
                  side: const BorderSide(color: Colors.black87, width: 1.0),
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Đăng xuất'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}