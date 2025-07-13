import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:datn_app/screens/auth_screen.dart'; // Đường dẫn đến file AuthScreen
import 'auth_screen_test.mocks.dart';

// Tạo các mock classes
@GenerateMocks([
  FirebaseAuth,
  UserCredential,
  GoogleSignIn,
  GoogleSignInAccount,
  GoogleSignInAuthentication,
  FacebookAuth
])
void main() {
  late MockFirebaseAuth mockFirebaseAuth;
  late MockUserCredential mockUserCredential;
  late MockGoogleSignIn mockGoogleSignIn;
  late MockGoogleSignInAccount mockGoogleSignInAccount;
  late MockGoogleSignInAuthentication mockGoogleSignInAuthentication;
  late MockFacebookAuth mockFacebookAuth;

  setUp(() {
    mockFirebaseAuth = MockFirebaseAuth();
    mockUserCredential = MockUserCredential();
    mockGoogleSignIn = MockGoogleSignIn();
    mockGoogleSignInAccount = MockGoogleSignInAccount();
    mockGoogleSignInAuthentication = MockGoogleSignInAuthentication();
    mockFacebookAuth = MockFacebookAuth();
  });

  // Hàm tạo widget AuthScreen với các mock
  Widget createAuthScreen() {
    return MaterialApp(
      home: AuthScreen(),
    );
  }

  group('AuthScreen Tests', () {
    testWidgets('Hiển thị giao diện đăng nhập', (WidgetTester tester) async {
      await tester.pumpWidget(createAuthScreen());

      expect(find.text('Đăng nhập'), findsOneWidget);
      expect(find.text('Email'), findsOneWidget);
      expect(find.text('Mật khẩu'), findsOneWidget);
      expect(find.text('Quên mật khẩu?'), findsOneWidget);
    });

    testWidgets('Hiển thị giao diện đăng ký khi chuyển đổi', (WidgetTester tester) async {
      await tester.pumpWidget(createAuthScreen());

      await tester.tap(find.text('Chưa có tài khoản? Đăng ký'));
      await tester.pumpAndSettle();

      expect(find.text('Đăng ký'), findsOneWidget);
      expect(find.text('Đã có tài khoản? Đăng nhập'), findsOneWidget);
    });

    testWidgets('Hiển thị lỗi khi nhập email không hợp lệ', (WidgetTester tester) async {
      await tester.pumpWidget(createAuthScreen());

      await tester.enterText(find.byType(TextField).first, 'invalid-email');
      await tester.enterText(find.byType(TextField).last, '123456');
      await tester.tap(find.text('Đăng nhập'));
      await tester.pumpAndSettle();

      expect(find.text('Vui lòng nhập email hợp lệ.'), findsOneWidget);
    });

    testWidgets('Hiển thị lỗi khi nhập mật khẩu ngắn', (WidgetTester tester) async {
      await tester.pumpWidget(createAuthScreen());

      await tester.enterText(find.byType(TextField).first, 'test@example.com');
      await tester.enterText(find.byType(TextField).last, '123');
      await tester.tap(find.text('Đăng nhập'));
      await tester.pumpAndSettle();

      expect(find.text('Mật khẩu phải có ít nhất 6 ký tự.'), findsOneWidget);
    });

    testWidgets('Đăng nhập thành công với email và mật khẩu', (WidgetTester tester) async {
      // Mock FirebaseAuth
      when(mockFirebaseAuth.signInWithEmailAndPassword(
        email: 'test@example.com',
        password: 'password123',
      )).thenAnswer((_) async => mockUserCredential);

      // Thay thế FirebaseAuth.instance bằng mock
      // (Bạn cần inject mockFirebaseAuth vào AuthScreen nếu sửa code gốc)

      await tester.pumpWidget(createAuthScreen());

      await tester.enterText(find.byType(TextField).first, 'test@example.com');
      await tester.enterText(find.byType(TextField).last, 'password123');
      await tester.tap(find.text('Đăng nhập'));
      await tester.pumpAndSettle();

      // Kiểm tra không hiển thị lỗi
      expect(find.text('Vui lòng nhập email hợp lệ.'), findsNothing);
      expect(find.text('Mật khẩu phải có ít nhất 6 ký tự.'), findsNothing);
    });

    testWidgets('Hiển thị dialog quên mật khẩu', (WidgetTester tester) async {
      await tester.pumpWidget(createAuthScreen());

      await tester.tap(find.text('Quên mật khẩu?'));
      await tester.pumpAndSettle();

      expect(find.text('Quên mật khẩu'), findsOneWidget);
      expect(find.text('Nhập email của bạn để nhận link đặt lại mật khẩu.'), findsOneWidget);
    });

    testWidgets('Đăng nhập bằng Google', (WidgetTester tester) async {
      // Mock Google Sign-In
      when(mockGoogleSignIn.signIn()).thenAnswer((_) async => mockGoogleSignInAccount);
      when(mockGoogleSignInAccount.authentication).thenAnswer((_) async => mockGoogleSignInAuthentication);
      when(mockGoogleSignInAuthentication.accessToken).thenReturn('access-token');
      when(mockGoogleSignInAuthentication.idToken).thenReturn('id-token');
      when(mockFirebaseAuth.signInWithCredential(any)).thenAnswer((_) async => mockUserCredential);

      await tester.pumpWidget(createAuthScreen());

      await tester.tap(find.text('Google'));
      await tester.pumpAndSettle();

      expect(find.text('Đăng nhập bằng Google thất bại'), findsNothing);
    });
  });
}