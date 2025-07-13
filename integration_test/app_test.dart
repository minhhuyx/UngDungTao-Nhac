import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:datn_app/main.dart' as app; // Thay 'your_app' bằng tên package của bạn

void main() {
  // Khởi tạo binding cho Integration Test
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Kiểm tra luồng đăng nhập', (WidgetTester tester) async {
    // Khởi động ứng dụng
    app.main();
    await tester.pumpAndSettle(); // Chờ ứng dụng tải xong

    // Tìm các trường nhập liệu và nút
    final emailField = find.byType(TextField).first;
    final passwordField = find.byType(TextField).last;
    final loginButton = find.text('Đăng nhập');

    // Nhập dữ liệu vào các trường
    await tester.enterText(emailField, 'test@example.com');
    await tester.enterText(passwordField, 'password123');
    await tester.pumpAndSettle(); // Cập nhật giao diện

    // Nhấn nút đăng nhập
    await tester.tap(loginButton);
    await tester.pumpAndSettle(); // Chờ chuyển màn hình

    // Kiểm tra xem đã chuyển sang màn hình chính chưa
    expect(find.text('Chào mừng'), findsOneWidget); // Giả sử màn hình chính có text "Chào mừng"
  });
}