import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:datn_app/screens/home_screen.dart';

void main() {
  // Hàm hỗ trợ để bọc widget trong MaterialApp với theme
  Widget createHomeScreen() {
    return MaterialApp(
      theme: ThemeData(
        brightness: Brightness.light,
        textTheme: GoogleFonts.beVietnamProTextTheme(),
      ),
      home: const HomeScreen(),
    );
  }

  group('Kiểm thử HomeScreen', () {
    // Kiểm tra giao diện HomeScreen hiển thị đúng
    testWidgets('HomeScreen hiển thị các thành phần UI chính', (WidgetTester tester) async {
      await tester.pumpWidget(createHomeScreen());

      // Kiểm tra tiêu đề AppBar
      expect(find.text('DIFFRHYTHM AI'), findsOneWidget);

      // Kiểm tra các tiêu đề phần
      expect(find.text('Lời Bài Hát:'), findsOneWidget);
      expect(find.text('Thời Lượng'), findsOneWidget);
      expect(find.text('Mô Tả Âm Thanh'), findsOneWidget);
      expect(find.text('Mô Tả Phong Cách'), findsOneWidget);
      expect(find.text('Tạo Nhạc'), findsOneWidget);

      // Kiểm tra nút "Tải âm thanh" và "Ghi âm"
      expect(find.text('Tải âm thanh'), findsOneWidget);
      expect(find.text('Ghi âm'), findsOneWidget);
    });

    // Kiểm tra trường nhập lời bài hát
    testWidgets('Trường nhập lời bài hát cập nhật đúng', (WidgetTester tester) async {
      await tester.pumpWidget(createHomeScreen());

      // Tìm trường TextField đầu tiên (lời bài hát)
      final lyricsField = find.byType(TextField).first;
      await tester.enterText(lyricsField, '[00:10.00] Test lyric line');
      await tester.pump();

      // Kiểm tra văn bản đã nhập
      expect(find.text('[00:10.00] Test lyric line'), findsOneWidget);
    });

    // Kiểm tra nút "Tạo Nhạc" hiển thị lỗi khi lời bài hát trống
    testWidgets('Nút Tạo Nhạc hiển thị lỗi khi lời bài hát trống', (WidgetTester tester) async {
      await tester.pumpWidget(createHomeScreen());

      // Nhấn nút "Tạo Nhạc"
      await tester.tap(find.text('Tạo Nhạc'));
      await tester.pump();

      // Kiểm tra thông báo lỗi
      expect(find.text('Vui lòng nhập lời bài hát!'), findsOneWidget);
    });

    // Kiểm tra nút "Tạo Nhạc" hiển thị lỗi khi lời bài hát sai định dạng
    testWidgets('Nút Tạo Nhạc hiển thị lỗi khi lời bài hát sai định dạng', (WidgetTester tester) async {
      await tester.pumpWidget(createHomeScreen());

      // Nhập lời bài hát sai định dạng
      final lyricsField = find.byType(TextField).first;
      await tester.enterText(lyricsField, '00:10.00 Test lyric');
      await tester.pump();

      // Chọn text prompt để vượt qua kiểm tra PromptType
      final promptField = find.byType(TextField).last;
      await tester.enterText(promptField, 'emotional piano pop');
      await tester.pump();

      // Nhấn nút "Tạo Nhạc"
      await tester.tap(find.text('Tạo Nhạc'));
      await tester.pump();

      // Kiểm tra thông báo lỗi định dạng
      expect(find.text('Lời bài hát không đúng định dạng [mm:ss.xx] Lyric content'), findsOneWidget);
    });

    // Kiểm tra ExpansionTile hiển thị hướng dẫn
    testWidgets('ExpansionTile hiển thị nội dung hướng dẫn đúng', (WidgetTester tester) async {
      await tester.pumpWidget(createHomeScreen());

      // Nhấn vào "Hướng Dẫn" để mở ExpansionTile
      await tester.tap(find.text('Hướng Dẫn'));
      await tester.pumpAndSettle();

      // Kiểm tra nội dung hướng dẫn
      expect(find.text('Yêu cầu về định dạng lời bài hát'), findsOneWidget);
      expect(find.text('[00:10.00] Moonlight spills through broken blinds'), findsOneWidget);
      expect(find.text('Ngôn ngữ hỗ trợ'), findsOneWidget);
    });
  });

  group('Kiểm thử buildMusicCard', () {
    // Kiểm tra buildMusicCard hiển thị đúng
    testWidgets('buildMusicCard hiển thị đúng với đường dẫn âm thanh', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: buildMusicCard(
              'test_audio.mp3',
              Colors.white,
              Colors.black87,
              TextEditingController(),
              tester.element(find.byType(Scaffold)),
                  () {},
            ),
          ),
        ),
      );

      // Kiểm tra tên file âm thanh và các nút
      expect(find.text('test_audio.mp3'), findsOneWidget);
      expect(find.byType(Slider), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow), findsOneWidget);
      expect(find.byIcon(Icons.favorite), findsOneWidget);
      expect(find.byIcon(Icons.close), findsOneWidget);
    });
  });
}