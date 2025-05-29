import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';


class LyricsHistoryManager {
  static const int maxLyrics = 5; // Giới hạn 5 lời bài hát

  Future<void> addLyricsToHistory({
    required String generatedLyrics,
    required String language,
    required String theme,
    required String tags,
    required String category, // Thêm category để phân biệt "my_songs" hoặc "favorites"
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('Người dùng chưa đăng nhập.');
    }

    final userId = user.uid;
    final databaseRef = FirebaseDatabase.instance.ref('lyrics_history/$userId');

    try {
      // Kiểm tra số lượng lời bài hát trong lịch sử
      final snapshot = await databaseRef.orderByChild('created_at').get();
      final lyricsEntries = <String, dynamic>{};
      if (snapshot.exists) {
        lyricsEntries.addAll(Map<String, dynamic>.from(snapshot.value as Map));
        print('Số lượng mục: ${lyricsEntries.length}');
      }

      if (lyricsEntries.length >= LyricsHistoryManager.maxLyrics) {
        // Xóa lời bài hát cũ nhất
        final oldestSnapshot = await databaseRef
            .orderByChild('created_at')
            .limitToFirst(1)
            .get();
        if (oldestSnapshot.exists) {
          final oldestKey = oldestSnapshot.children.first.key;
          print('Xóa mục cũ nhất: $oldestKey');
          await databaseRef.child(oldestKey!).remove();
        }
      }

      // Thêm lời bài hát mới
      final newLyricsRef = databaseRef.push();
      final localTime = DateTime.now();
      print('Thời gian thiết bị trước khi lưu: ${DateFormat('dd/MM/yyyy HH:mm:ss').format(localTime)}');
      print('Device Timestamp trước khi lưu: ${localTime.millisecondsSinceEpoch}');
      await newLyricsRef.set({
        'generated_lyrics': generatedLyrics,
        'language': language,
        'theme': theme,
        'tags': tags,
        'category': category, // Lưu category vào dữ liệu
        'created_at': ServerValue.timestamp,
      });
      print('Đã lưu dữ liệu vào: ${newLyricsRef.key}');

      // Kiểm tra chênh lệch thời gian
      final savedSnapshot = await newLyricsRef.get();
      if (savedSnapshot.exists) {
        final savedData = Map<String, dynamic>.from(savedSnapshot.value as Map);
        final createdAt = savedData['created_at'] as int?;
        final deviceTime = localTime.millisecondsSinceEpoch;
        if (createdAt != null && (createdAt - deviceTime).abs() > 10000) {
          print('Cảnh báo: Chênh lệch thời gian lớn: created_at=$createdAt, device_time=$deviceTime');
        }
      }
    } catch (e) {
      print('Lỗi khi thêm lời bài hát vào lịch sử: $e');
      rethrow;
    }
  }
}

class LyricsScreen extends StatefulWidget {
  const LyricsScreen({Key? key}) : super(key: key);

  @override
  _LyricsScreenState createState() => _LyricsScreenState();
}

class _LyricsScreenState extends State<LyricsScreen> {
  String _selectedLanguage = 'en';
  final _themeController = TextEditingController(text: '');
  final _tagsMethod1Controller = TextEditingController(text: '');
  final _tagsMethod2Controller = TextEditingController(text: '');
  final _rawLyricsController = TextEditingController();
  String _generatedLyrics = '';
  String _currentTheme = '';
  String _currentTags = '';

  final _themeFocusNode = FocusNode();
  final _tagsMethod2FocusNode = FocusNode();

  final LyricsHistoryManager _historyManager = LyricsHistoryManager();

  final highlightColor = const Color(0xFFADD8E6);

  // Danh sách các mô hình AI
  final List<String> _models = [
    'Phi-4',              // Phi-4 (Microsoft)
    'DeepSeek-V3-0324',   // DeepSeek-V3-0324 (DeepSeek)
    'gpt-4o',             // OpenAI GPT-4o
  ];
  String _selectedModel = 'gpt-4o';
  String _selectedModel2 = 'gpt-4o';// Mô hình mặc định

  // Kiểm tra kết nối và múi giờ
  Future<bool> _checkConnectionAndTimeZone() async {
    bool isConnected = await FirebaseDatabase.instance
        .ref()
        .child('.info/connected')
        .once()
        .then((event) => event.snapshot.exists);
    if (!isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không có kết nối mạng. Vui lòng thử lại.')),
      );
      return false;
    }

    final now = DateTime.now();
    print('Thời gian thiết bị: ${DateFormat('dd/MM/yyyy HH:mm:ss').format(now)}');
    print('Múi giờ: ${now.timeZoneName}, Offset: ${now.timeZoneOffset}');
    print('Device Timestamp: ${now.millisecondsSinceEpoch}');
    return true;
  }

  // Method 1: Generate from Theme with Timestamps
  Future<void> _generateLyricsFromTheme() async {
    final theme = _themeController.text.trim();
    final tags = _tagsMethod1Controller.text.trim();

    if (theme.isEmpty || tags.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter theme and tags')),
      );
      return;
    }

    try {
      // Lấy baseApiUrl và apiKey từ file .env
      final String baseApiUrl = dotenv.env['baseApiUrl_Lyrics'] ?? '';
      final String apiKey = dotenv.env['apiKey_Lyrics'] ?? '';
      final String apiUrl = '$baseApiUrl/chat/completions';

      if (baseApiUrl.isEmpty || apiKey.isEmpty) {
        throw Exception('API URL or API Key is missing in .env file');
      }

      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'Authorization': 'Bearer $apiKey',
          'x-ms-model-mesh-model-name': _selectedModel,
        },
        body: jsonEncode({
          'messages': [
            {
              'role': 'user',
              'content':
              'Write high-quality song lyrics based on the theme "$theme" and style "$tags" (e.g., piano slow).\n'
                  'Language: ${_selectedLanguage == 'en' ? 'English' : 'Chinese'}\n'
                  'Structure: at least 2 verses, 1–2 choruses, and optionally a bridge\n'
                  'Duration: lyrics should cover around 3 minutes (~45–60 lines)\n'
                  'Add a timestamp at the beginning of each line, e.g.:\n'
                  '[00:00] The rain falls soft on shattered dreams\n'
                  '[00:04] A heart undone by silent screams\n'
                  'Use vivid imagery, emotional depth, and natural rhymes\n'
                  'Make sure the lyrics are musically rhythmic and suitable for singing\n'
                  'After generation, refine the lyrics for cohesion, emotion, and lyrical flow',
            },
          ],
          'max_tokens': 3000,
          'temperature': 1.0,
          'top_p': 1.0,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes, allowMalformed: true));
        final generatedLyrics = data['choices'][0]['message']['content'];
        setState(() {
          _generatedLyrics = generatedLyrics;
          _currentTheme = theme;
          _currentTags = tags;
          _themeController.clear();
          _tagsMethod1Controller.clear();
          FocusScope.of(context).requestFocus(_themeFocusNode);
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Lyrics generated!')),
        );
      } else {
        throw Exception(
          'Failed to generate lyrics: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      print('Error generating lyrics: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  // Method 2: Simply Add Timestamps to Raw Lyrics
  Future<void> _addTimestampsToLyrics() async {
    final tags = _tagsMethod2Controller.text.trim();
    final rawLyrics = _rawLyricsController.text.trim();

    if (rawLyrics.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter raw lyrics')),
      );
      return;
    }

    try {
      // Lấy baseApiUrl và apiKey từ file .env
      final String baseApiUrl = dotenv.env['baseApiUrl_Lyrics'] ?? '';
      final String apiKey = dotenv.env['apiKey_Lyrics'] ?? '';
      final String apiUrl = '$baseApiUrl/chat/completions';

      if (baseApiUrl.isEmpty || apiKey.isEmpty) {
        throw Exception('API URL or API Key is missing in .env file');
      }

      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'Authorization': 'Bearer $apiKey',
          'x-ms-model-mesh-model-name': _selectedModel2,
        },
        body: jsonEncode({
          'messages': [
            {
              'role': 'user',
              'content':
              'Add timestamps (e.g., [MM:SS]) to the following lyrics in ${_selectedLanguage == 'en' ? 'English' : 'Chinese'} format, based on the style tags "$tags" and a typical song tempo. Do not modify or enhance the lyrics, just add timestamps:\n\n$rawLyrics',
            },
          ],
          'max_tokens': 3000,
          'temperature': 1.0,
          'top_p': 1.0,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes, allowMalformed: true));
        final generatedLyrics = data['choices'][0]['message']['content'];
        setState(() {
          _generatedLyrics = generatedLyrics;
          _currentTheme = '';
          _currentTags = tags;
          _rawLyricsController.clear();
          _tagsMethod2Controller.clear();
          FocusScope.of(context).requestFocus(_tagsMethod2FocusNode);
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Timestamps added!')),
        );
      } else {
        throw Exception(
          'Failed to add timestamps: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      print('Error adding timestamps: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  // Hàm lưu lời bài hát vào Firebase
  // Hàm lưu lời bài hát vào Firebase
  // Hàm lưu lời bài hát vào Firebase
  Future<void> _saveLyrics() async {
    if (_generatedLyrics.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không có lời bài hát để lưu')),
      );
      return;
    }

    if (!await _checkConnectionAndTimeZone()) return;

    try {
      await _historyManager.addLyricsToHistory(
        generatedLyrics: _generatedLyrics,
        language: _selectedLanguage,
        theme: _currentTheme,
        tags: _currentTags,
        category: 'favorites', // Đặt category là "favorites"
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã lưu lời bài hát vào lịch sử!')),
      );
    } catch (e) {
      print('Lỗi khi lưu lời bài hát: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi khi lưu lời bài hát: $e')),
      );
    }
  }

  // Hàm sao chép lời bài hát
  void _copyLyricsToClipboard() {
    Clipboard.setData(ClipboardData(text: _generatedLyrics));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Lyrics copied to clipboard!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Xác định màu chữ và theme
    final textColor = Theme.of(context).brightness == Brightness.dark
        ? Colors.white // Màu trắng cho dark theme
        : Colors.black; // Màu đen cho light theme
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;

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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Notice Card
            Card(
              color: const Color(0xFFADD8E6),
              elevation: 6,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: isDarkTheme
                    ? const BorderSide(color: Color(0xFFADD8E6), width: 1.5)
                    : BorderSide.none,
              ),
              child: ExpansionTile(
                title: Text(
                  'Notice',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                collapsedBackgroundColor: const Color(0xFFADD8E6),
                shape: const Border(),
                collapsedShape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(15.0),
                    child: Text(
                      'Two Generation Modes:\n1. Generate from theme & tags with timestamps\n2. Add timestamps to existing lyrics',
                      style: GoogleFonts.raleway(
                        fontSize: 15,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 15),
            // Input Card
            Card(
              color: isDarkTheme ? Colors.black : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: const BorderSide(color: Color(0xFFADD8E6), width: 1.0)
              ),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Method 1
                    Text(
                      'Method 1: Generate from Theme ',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 15),
                    Text(
                      'Theme',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 15),
                    Theme(
                      data: Theme.of(context).copyWith(
                        inputDecorationTheme: const InputDecorationTheme(
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(10)),
                            borderSide: BorderSide(
                              color: Color(0xFFADD8E6),
                              width: 3.0,
                            ),
                          ),
                        ),
                      ),
                      child: TextField(
                        controller: _themeController,
                        focusNode: _themeFocusNode,
                        style: GoogleFonts.raleway(
                          fontSize: 15,
                          color: textColor,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Enter song theme,e.g: Love and Heartbreak',
                          hintStyle: GoogleFonts.raleway(
                            fontSize: 18,
                            color: isDarkTheme ? Colors.grey : Colors.grey,
                          ),
                          filled: true,
                          fillColor: isDarkTheme ? Colors.white : Colors.white,
                          border: const OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(10)),
                          ),
                          enabledBorder: const OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(10)),
                            borderSide: BorderSide(
                              color: Color(0xFFADD8E6),
                              width: 1.0,
                            ),
                          ),
                          focusedBorder: const OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(10)),
                            borderSide: BorderSide(
                              color: Color(0xFFADD8E6),
                              width: 3.0,
                            ),
                          ),
                          focusColor: const Color(0xFFADD8E6),
                        ),
                      ),
                    ),
                    const SizedBox(height: 15),
                    Text(
                      'Tags ',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 15),
                    Theme(
                      data: Theme.of(context).copyWith(
                        inputDecorationTheme: const InputDecorationTheme(
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(10)),
                            borderSide: BorderSide(
                              color: Color(0xFFADD8E6),
                              width: 3.0,
                            ),
                          ),
                        ),
                      ),
                      child: TextField(
                        controller: _tagsMethod1Controller,
                        style: GoogleFonts.raleway(
                          fontSize: 15,
                          color: textColor,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Enter song tags,eg: pop confidence healing',
                          hintStyle: GoogleFonts.raleway(
                            fontSize: 18,
                            color: isDarkTheme ? Colors.grey : Colors.grey,
                          ),
                          filled: true,
                          fillColor: isDarkTheme ? Colors.white : Colors.white,
                          border: const OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(10)),
                          ),
                          enabledBorder: const OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(10)),
                            borderSide: BorderSide(
                              color: Color(0xFFADD8E6),
                              width: 1.0,
                            ),
                          ),
                          focusedBorder: const OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(10)),
                            borderSide: BorderSide(
                              color: Color(0xFFADD8E6),
                              width: 3.0,
                            ),
                          ),
                          focusColor: const Color(0xFFADD8E6),
                        ),
                      ),
                    ),
                    const SizedBox(height: 15),
                    Text(
                      'Language',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 15),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Expanded(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Transform.scale(
                                scale: 1.1,
                                child: Radio<String>(
                                  value: 'en',
                                  groupValue: _selectedLanguage,
                                  activeColor: const Color(0xFFADD8E6),
                                  fillColor: MaterialStateProperty.resolveWith<Color>((states) {
                                    if (states.contains(MaterialState.selected)) {
                                      return const Color(0xFFADD8E6);
                                    }
                                    return isDarkTheme ? Colors.white70 : Colors.black54;
                                  }),
                                  onChanged: (value) {
                                    setState(() => _selectedLanguage = value!);
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'English',
                                style: GoogleFonts.raleway(
                                  fontSize: 15,
                                  color: isDarkTheme ? Colors.white : Colors.black,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Transform.scale(
                                scale: 1.1,
                                child: Radio<String>(
                                  value: 'cn',
                                  groupValue: _selectedLanguage,
                                  activeColor: const Color(0xFFADD8E6),
                                  fillColor: MaterialStateProperty.resolveWith<Color>((states) {
                                    if (states.contains(MaterialState.selected)) {
                                      return const Color(0xFFADD8E6);
                                    }
                                    return isDarkTheme ? Colors.white70 : Colors.black54;
                                  }),
                                  onChanged: (value) {
                                    setState(() => _selectedLanguage = value!);
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Chinese',
                                style: GoogleFonts.raleway(
                                  fontSize: 15,
                                  color: isDarkTheme ? Colors.white : Colors.black,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),
                    Text(
                      'Model AI',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 15),
                    Padding(
                      padding: const EdgeInsets.all(10.0),
                      child: DropdownButton<String>(
                        value: _selectedModel,
                        isExpanded: true,
                        hint: const Text('Chọn mô hình AI / Select AI model'),
                        items: _models.map((String model) {
                          return DropdownMenuItem<String>(
                            value: model,
                            child: Text(model),
                          );
                        }).toList(),
                        onChanged: (String? newValue) {
                          if (newValue != null) {
                            setState(() {
                              _selectedModel = newValue;
                            });
                          }
                        },
                      ),
                    ),
                    const SizedBox(height: 15),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _generateLyricsFromTheme,
                        style: ElevatedButton.styleFrom(
                          side: const BorderSide(
                              color: Colors.black87, width: 1.0),
                          backgroundColor: const Color(0xFFADD8E6),
                          foregroundColor: Colors.black87,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Generate LRC (From Theme)',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 15),
                    // Method 2
                    Text(
                      'Method 2: Add Timestamps to Lyrics',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 15),
                    Text(
                      'Tags',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 15),
                    Theme(
                      data: Theme.of(context).copyWith(
                        inputDecorationTheme: const InputDecorationTheme(
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(10)),
                            borderSide: BorderSide(
                              color: Color(0xFFADD8E6),
                              width: 3.0,
                            ),
                          ),
                        ),
                      ),
                      child: TextField(
                        controller: _tagsMethod2Controller,
                        focusNode: _tagsMethod2FocusNode,
                        style: GoogleFonts.raleway(
                          fontSize: 15,
                          color: textColor,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Enter song tags,eg: ballad piano slow',
                          hintStyle: GoogleFonts.raleway(
                            fontSize: 18,
                            color: isDarkTheme ? Colors.grey : Colors.grey,
                          ),
                          filled: true,
                          fillColor: isDarkTheme ? Colors.white : Colors.white,
                          border: const OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(10)),
                          ),
                          enabledBorder: const OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(10)),
                            borderSide: BorderSide(
                              color: Color(0xFFADD8E6),
                              width: 1.0,
                            ),
                          ),
                          focusedBorder: const OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(10)),
                            borderSide: BorderSide(
                              color: Color(0xFFADD8E6),
                              width: 3.0,
                            ),
                          ),
                          focusColor: const Color(0xFFADD8E6),
                        ),
                      ),
                    ),
                    const SizedBox(height: 15),
                    Text(
                      'Raw Lyrics (without timestamps)',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 15),
                    Theme(
                      data: Theme.of(context).copyWith(
                        inputDecorationTheme: const InputDecorationTheme(
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(10)),
                            borderSide: BorderSide(
                              color: Color(0xFFADD8E6),
                              width: 3.0,
                            ),
                          ),
                        ),
                      ),
                      child: TextField(
                        controller: _rawLyricsController,
                        maxLines: 5,
                        style: GoogleFonts.raleway(
                          fontSize: 15,
                          color: textColor,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Enter plain lyrics,eg:\n'
                              'Yesterday\n'
                              'All my troubles',
                          hintStyle: GoogleFonts.raleway(
                            fontSize: 18,
                            color: isDarkTheme ? Colors.grey : Colors.grey,
                          ),
                          filled: true,
                          fillColor: isDarkTheme ? Colors.white : Colors.white,
                          border: const OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(10)),
                          ),
                          enabledBorder: const OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(10)),
                            borderSide: BorderSide(
                              color: Color(0xFFADD8E6),
                              width: 1.0,
                            ),
                          ),
                          focusedBorder: const OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(10)),
                            borderSide: BorderSide(
                              color: Color(0xFFADD8E6),
                              width: 3.0,
                            ),
                          ),
                          focusColor: const Color(0xFFADD8E6),
                        ),
                      ),
                    ),
                    const SizedBox(height: 15),
                    Text(
                      'Model AI',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 15),
                    Padding(
                      padding: const EdgeInsets.all(10.0),
                      child: DropdownButton<String>(
                        value: _selectedModel2,
                        isExpanded: true,
                        items: _models.map((String model) {
                          return DropdownMenuItem<String>(
                            value: model,
                            child: Text(model),
                          );
                        }).toList(),
                        onChanged: (String? newValue) {
                          if (newValue != null) {
                            setState(() {
                              _selectedModel2 = newValue;
                            });
                          }
                        },
                      ),

                    ),
                    const SizedBox(height: 15),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _addTimestampsToLyrics,
                        style: ElevatedButton.styleFrom(
                          side: const BorderSide(
                              color: Colors.black87, width: 1.0),
                          backgroundColor: const Color(0xFFADD8E6),
                          foregroundColor: Colors.black87,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Generate LRC (From Lyrics)',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 15),
            // Card displaying lyrics with copy and save buttons
            if (_generatedLyrics.isNotEmpty)
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: isDarkTheme
                      ? const BorderSide(color: Color(0xFFADD8E6), width: 1.5)
                      : BorderSide.none,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Generated Lyrics',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.copy),
                                onPressed: _copyLyricsToClipboard,
                                tooltip: 'Copy lyrics',
                              ),
                              IconButton(
                                icon: const Icon(Icons.save),
                                onPressed: _saveLyrics,
                                tooltip: 'Save lyrics',
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 15),
                      Text(
                        _generatedLyrics,
                        style: const TextStyle(fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _themeController.dispose();
    _tagsMethod1Controller.dispose();
    _tagsMethod2Controller.dispose();
    _rawLyricsController.dispose();
    _themeFocusNode.dispose();
    _tagsMethod2FocusNode.dispose();
    super.dispose();
  }
}