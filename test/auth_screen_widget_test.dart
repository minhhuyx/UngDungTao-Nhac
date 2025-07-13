import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:datn_app/screens/auth_screen.dart'; // Đường dẫn đến file AuthScreen

void main() {
  // Hàm tạo widget AuthScreen
  Widget createAuthScreen() {
    return MaterialApp(
      home: AuthScreen(),
    );
  }

  group('AuthScreen Widget Tests', () {
    testWidgets('Hiển thị giao diện đăng nhập mặc định', (WidgetTester tester) async {
      await tester.pumpWidget(createAuthScreen());

      // Kiểm tra tiêu đề "Đăng nhập"
      expect(find.text('Đăng nhập'), findsOneWidget);
      // Kiểm tra các trường nhập liệu
      expect(find.text('Email'), findsOneWidget);
      expect(find.text('Mật khẩu'), findsOneWidget);
      // Kiểm tra nút "Quên mật khẩu?"
      expect(find.text('Quên mật khẩu?'), findsOneWidget);
      // Kiểm tra các nút đăng nhập bằng Google, Facebook, Phone
      expect(find.text('Google'), findsOneWidget);
      expect(find.text('Facebook'), findsOneWidget);
      expect(find.text('Phone'), findsOneWidget);
      // Kiểm tra nút chuyển sang đăng ký
      expect(find.text('Chưa có tài khoản? Đăng ký'), findsOneWidget);
      // Kiểm tra AppBar
      expect(find.text('MUSIC AI'), findsOneWidget);
    });

    testWidgets('Chuyển sang giao diện đăng ký khi nhấn nút', (WidgetTester tester) async {
      await tester.pumpWidget(createAuthScreen());

      // Nhấn nút chuyển sang đăng ký
      await tester.tap(find.text('Chưa có tài khoản? Đăng ký'));
      await tester.pumpAndSettle();

      // Kiểm tra tiêu đề "Đăng ký"
      expect(find.text('Đăng ký'), findsOneWidget);
      // Kiểm tra nút chuyển về đăng nhập
      expect(find.text('Đã có tài khoản? Đăng nhập'), findsOneWidget);
      // Kiểm tra nút "Quên mật khẩu?" không hiển thị ở chế độ đăng ký
      expect(find.text('Quên mật khẩu?'), findsNothing);
    });

    testWidgets('Hiển thị dialog quên mật khẩu khi nhấn nút', (WidgetTester tester) async {
      await tester.pumpWidget(createAuthScreen());

      // Nhấn nút "Quên mật khẩu?"
      await tester.tap(find.text('Quên mật khẩu?'));
      await tester.pumpAndSettle();

      // Kiểm tra dialog hiển thị
      expect(find.text('Quên mật khẩu'), findsOneWidget);
      expect(find.text('Nhập email của bạn để nhận link đặt lại mật khẩu.'), findsOneWidget);
      expect(find.text('Hủy'), findsOneWidget);
      expect(find.text('Gửi'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('Hiển thị dialog đăng nhập bằng số điện thoại khi nhấn nút', (WidgetTester tester) async {
      await tester.pumpWidget(createAuthScreen());

      // Nhấn nút "Phone"
      await tester.tap(find.text('Phone'));
      await tester.pumpAndSettle();

      // Kiểm tra dialog hiển thị
      expect(find.text('Đăng nhập bằng số điện thoại'), findsOneWidget);
      expect(find.text('Nhập số điện thoại của bạn (bao gồm mã quốc gia, ví dụ: +84).'), findsOneWidget);
      expect(find.text('Hủy'), findsOneWidget);
      expect(find.text('Gửi mã'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('Hiển thị thông báo lỗi khi nhấn đăng nhập với email không hợp lệ', (WidgetTester tester) async {
      await tester.pumpWidget(createAuthScreen());

      // Nhập email không hợp lệ
      await tester.enterText(find.byType(TextField).first, 'invalid-email');
      await tester.enterText(find.byType(TextField).last, '123456');
      await tester.tap(find.text('Đăng nhập'));
      await tester.pumpAndSettle();

      // Kiểm tra thông báo lỗi
      expect(find.text('Vui lòng nhập email hợp lệ.'), findsOneWidget);
    });

    testWidgets('Hiển thị thông báo lỗi khi nhấn đăng nhập với mật khẩu ngắn', (WidgetTester tester) async {
      await tester.pumpWidget(createAuthScreen());

      // Nhập mật khẩu ngắn
      await tester.enterText(find.byType(TextField).first, 'test@example.com');
      await tester.enterText(find.byType(TextField).last, '123');
      await tester.tap(find.text('Đăng nhập'));
      await tester.pumpAndSettle();

      // Kiểm tra thông báo lỗi
      expect(find.text('Mật khẩu phải có ít nhất 6 ký tự.'), findsOneWidget);
    });
  });
}