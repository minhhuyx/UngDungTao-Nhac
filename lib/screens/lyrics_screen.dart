import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LyricsHistoryManager {
  static const int maxLyrics = 5; // Giới hạn 5 lời bài hát

  Future<void> addLyricsToHistory({
    required String generatedLyrics,
    required String language,
    required String theme,
    required String tags,
    required String category,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('Người dùng chưa đăng nhập.');
    }

    final userId = user.uid;
    final databaseRef = FirebaseDatabase.instance.ref('lyrics_history/$userId');

    try {
      final snapshot = await databaseRef.orderByChild('created_at').get();
      final lyricsEntries = <String, dynamic>{};
      if (snapshot.exists) {
        lyricsEntries.addAll(Map<String, dynamic>.from(snapshot.value as Map));
        print('Số lượng mục: ${lyricsEntries.length}');
      }

      if (lyricsEntries.length >= LyricsHistoryManager.maxLyrics) {
        final oldestSnapshot =
            await databaseRef.orderByChild('created_at').limitToFirst(1).get();
        if (oldestSnapshot.exists) {
          final oldestKey = oldestSnapshot.children.first.key;
          print('Xóa mục cũ nhất: $oldestKey');
          await databaseRef.child(oldestKey!).remove();
        }
      }

      final newLyricsRef = databaseRef.push();
      final localTime = DateTime.now();
      print(
        'Thời gian thiết bị trước khi lưu: ${DateFormat('dd/MM/yyyy HH:mm:ss').format(localTime)}',
      );
      print(
        'Device Timestamp trước khi lưu: ${localTime.millisecondsSinceEpoch}',
      );
      await newLyricsRef.set({
        'generated_lyrics': generatedLyrics,
        'language': language,
        'theme': theme,
        'tags': tags,
        'category': category,
        'created_at': ServerValue.timestamp,
      });
      print('Đã lưu dữ liệu vào: ${newLyricsRef.key}');

      final savedSnapshot = await newLyricsRef.get();
      if (savedSnapshot.exists) {
        final savedData = Map<String, dynamic>.from(savedSnapshot.value as Map);
        final createdAt = savedData['created_at'] as int?;
        final deviceTime = localTime.millisecondsSinceEpoch;
        if (createdAt != null && (createdAt - deviceTime).abs() > 10000) {
          print(
            'Cảnh báo: Chênh lệch thời gian lớn: created_at=$createdAt, device_time=$deviceTime',
          );
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
  bool _isLoading = false;
  bool _isSaved = false;

  final _themeFocusNode = FocusNode();
  final _tagsMethod2FocusNode = FocusNode();

  final LyricsHistoryManager _historyManager = LyricsHistoryManager();

  final highlightColor = const Color(0xFFADD8E6);

  final List<String> _models = ['Phi-4', 'DeepSeek-V3-0324', 'gpt-4o','Grok-3'];
  String _selectedModel = 'gpt-4o';
  String _selectedModel2 = 'gpt-4o';

  @override
  void initState() {
    super.initState();
    _loadSavedState();
  }

  Future<void> _loadSavedState() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _generatedLyrics = prefs.getString('lyrics_generatedLyrics') ?? '';
      _currentTheme = prefs.getString('lyrics_currentTheme') ?? '';
      _currentTags = prefs.getString('lyrics_currentTags') ?? '';
      _selectedLanguage = prefs.getString('lyrics_selectedLanguage') ?? 'en';
      _selectedModel = prefs.getString('lyrics_selectedModel') ?? 'gpt-4o'; // Mặc định cho tạo lời nhạc
      _selectedModel2 = prefs.getString('lyrics_selectedModel2') ?? 'Phi-4'; // Mặc định cho định dạng thời gian
      _isSaved = prefs.getBool('lyrics_isSaved') ?? false;
    });
  }

  Future<void> _saveState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('lyrics_generatedLyrics', _generatedLyrics);
    await prefs.setString('lyrics_currentTheme', _currentTheme);
    await prefs.setString('lyrics_currentTags', _currentTags);
    await prefs.setString('lyrics_selectedLanguage', _selectedLanguage);
    await prefs.setString('lyrics_selectedModel', _selectedModel);
    await prefs.setString('lyrics_selectedModel2', _selectedModel2);
    await prefs.setBool('lyrics_isSaved', _isSaved);
  }

  Future<void> _deleteLyrics() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _generatedLyrics = '';
      _currentTheme = '';
      _currentTags = '';
      _isSaved = false;
    });
    await prefs.remove('lyrics_generatedLyrics');
    await prefs.remove('lyrics_currentTheme');
    await prefs.remove('lyrics_currentTags');
    await prefs.setBool('lyrics_isSaved', false);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Đã xóa lời bài hát!')));
  }

  Future<bool> _checkConnectionAndTimeZone() async {
    bool isConnected = await FirebaseDatabase.instance
        .ref()
        .child('.info/connected')
        .once()
        .then((event) => event.snapshot.exists);
    if (!isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Không có kết nối mạng. Vui lòng thử lại.'),
        ),
      );
      return false;
    }

    final now = DateTime.now();
    print(
      'Thời gian thiết bị: ${DateFormat('dd/MM/yyyy HH:mm:ss').format(now)}',
    );
    print('Múi giờ: ${now.timeZoneName}, Offset: ${now.timeZoneOffset}');
    print('Device Timestamp: ${now.millisecondsSinceEpoch}');
    return true;
  }

  Future<void> _generateLyricsFromTheme() async {
    final theme = _themeController.text.trim();
    final tags = _tagsMethod1Controller.text.trim();

    if (theme.isEmpty || tags.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter theme and tags')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _isSaved = false;
      _generatedLyrics = ''; // Clear the displayed lyrics
    });

    try {
      final String baseApiUrl = dotenv.env['baseApiUrl_Lyrics'] ?? '';
      final String apiKey = dotenv.env['apiKey_Lyrics'] ?? '';
      final String apiUrl = '$baseApiUrl/chat/completions';

      if (baseApiUrl.isEmpty || apiKey.isEmpty) {
        throw Exception('API URL or API Key is missing');
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
              'content': '''
                      Write song lyrics for theme "$theme" in style ($tags).
                      Language: ${_selectedLanguage == 'en' ? 'English' : 'Chinese'}
                      Length: ~3 min (~45–60 lines)
                      Timestamps: [MM:SS.MS], e.g., [00:04.34], incrementing for ~3 min
                      Use vivid imagery, natural rhymes, with each line after its timestamp
''',
            },
          ],
          'max_tokens': 2000,
          'temperature': 1.0,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final generatedLyrics = data['choices'][0]['message']['content'];
        setState(() {
          _generatedLyrics = generatedLyrics;
          _currentTheme = theme;
          _currentTags = tags;
          _themeController.clear();
          _tagsMethod1Controller.clear();
          _isLoading = false;
        });
        await _saveState();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Lyrics generated!')));
      } else {
        throw Exception('Failed to generate lyrics');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _addTimestampsToLyrics() async {
    final tags = _tagsMethod2Controller.text.trim();
    final rawLyrics = _rawLyricsController.text.trim();

    if (rawLyrics.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter raw lyrics')));
      return;
    }

    setState(() {
      _isLoading = true;
      _isSaved = false;
      _generatedLyrics = ''; // Clear the displayed lyrics
    });

    try {
      final String baseApiUrl = dotenv.env['baseApiUrl_Lyrics'] ?? '';
      final String apiKey = dotenv.env['apiKey_Lyrics'] ?? '';
      final String apiUrl = '$baseApiUrl/chat/completions';

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
                  'Add timestamps to the lyrics in ${_selectedLanguage} format, based on tags "$tags":\n\n$rawLyrics',
            },
          ],
          'max_tokens': 2000,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final generatedLyrics = data['choices'][0]['message']['content'];
        setState(() {
          _generatedLyrics = generatedLyrics;
          _currentTheme = '';
          _currentTags = tags;
          _rawLyricsController.clear();
          _tagsMethod2Controller.clear();
          _isLoading = false;
        });
        await _saveState();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Timestamps added!')));
      } else {
        throw Exception('Failed to add timestamps');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _saveLyrics() async {
    try {
      await _historyManager.addLyricsToHistory(
        generatedLyrics: _generatedLyrics,
        language: _selectedLanguage,
        theme: _currentTheme,
        tags: _currentTags,
        category: 'favorites',
      );
      setState(() {
        _isSaved = true;
      });
      await _saveState();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Đã lưu thành công!')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Lỗi khi lưu: $e')));
    }
  }

  void _copyLyricsToClipboard() {
    Clipboard.setData(ClipboardData(text: _generatedLyrics));
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Lyrics copied!')));
  }

  @override
  Widget build(BuildContext context) {
    final textColor =
        Theme.of(context).brightness == Brightness.dark
            ? Colors.white
            : Colors.black;
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text('SÁNG TÁC BÀI HÁT', style: GoogleFonts.beVietnamPro()),
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
            Card(
              color: const Color(0xFFADD8E6),
              elevation: 6,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side:
                    isDarkTheme
                        ? const BorderSide(color: Color(0xFFADD8E6), width: 1.5)
                        : BorderSide.none,
              ),
              child: ExpansionTile(
                title: Text(
                  'Hướng Dẫn',
                  style: GoogleFonts.beVietnamPro(
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
                    child: Container(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Hai chế độ tạo lời bài hát:\n1. Tạo từ chủ đề và phong cách.\n2. Cập nhật định dạng cho lời nhạc.',
                        style: GoogleFonts.beVietnamPro(
                          fontSize: 15,
                          color: Colors.black,
                        ),
                        textAlign: TextAlign.left,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 15),
            Card(
              color: isDarkTheme ? Colors.black : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: const BorderSide(color: Color(0xFFADD8E6), width: 1.0),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tạo lời nhạc theo phong cách',
                      style: GoogleFonts.beVietnamPro(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 15),
                    Text(
                      'Chủ đề',
                      style: GoogleFonts.beVietnamPro(
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
                        style: GoogleFonts.beVietnamPro(
                          fontSize: 15,
                          color: textColor,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Nhập chủ đề,vd: Love and Heartbreak',
                          hintStyle: GoogleFonts.beVietnamPro(
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
                      'Phong cách',
                      style: GoogleFonts.beVietnamPro(
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
                        style: GoogleFonts.beVietnamPro(
                          fontSize: 15,
                          color: textColor,
                        ),
                        decoration: InputDecoration(
                          hintText:
                              'Nhập phong cách,vd: pop confidence healing',
                          hintStyle: GoogleFonts.beVietnamPro(
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
                      'Ngôn Ngữ',
                      style: GoogleFonts.beVietnamPro(
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
                                  fillColor:
                                      MaterialStateProperty.resolveWith<Color>((
                                        states,
                                      ) {
                                        if (states.contains(
                                          MaterialState.selected,
                                        )) {
                                          return const Color(0xFFADD8E6);
                                        }
                                        return isDarkTheme
                                            ? Colors.white70
                                            : Colors.black54;
                                      }),
                                  onChanged: (value) {
                                    setState(() {
                                      _selectedLanguage = value!;
                                      _saveState();
                                    });
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Tiếng Anh',
                                style: GoogleFonts.beVietnamPro(
                                  fontSize: 15,
                                  color:
                                      isDarkTheme ? Colors.white : Colors.black,
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
                                  fillColor:
                                      MaterialStateProperty.resolveWith<Color>((
                                        states,
                                      ) {
                                        if (states.contains(
                                          MaterialState.selected,
                                        )) {
                                          return const Color(0xFFADD8E6);
                                        }
                                        return isDarkTheme
                                            ? Colors.white70
                                            : Colors.black54;
                                      }),
                                  onChanged: (value) {
                                    setState(() {
                                      _selectedLanguage = value!;
                                      _saveState();
                                    });
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Tiếng Trung',
                                style: GoogleFonts.beVietnamPro(
                                  fontSize: 15,
                                  color:
                                      isDarkTheme ? Colors.white : Colors.black,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),
                    Text(
                      'Mô Hình AI',
                      style: GoogleFonts.beVietnamPro(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 15),
                     DropdownButtonFormField<String>(
                        value: _selectedModel,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: 'Chọn mô hình AI',
                          labelStyle: TextStyle(
                            color: isDarkTheme ? highlightColor : Colors.grey[400],
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                              color: highlightColor,
                              width: 1.0,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                              color: highlightColor,
                              width: 2.0,
                            ),
                          ),
                          border: const OutlineInputBorder(),
                        ),
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
                              _saveState();
                            });
                          }
                        },
                      ),
                    const SizedBox(height: 15),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _generateLyricsFromTheme,
                        style: ElevatedButton.styleFrom(
                          side: const BorderSide(
                            color: Colors.black87,
                            width: 1.0,
                          ),
                          backgroundColor: const Color(0xFFADD8E6),
                          foregroundColor: Colors.black87,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Tạo Lời Nhạc',
                          style: GoogleFonts.beVietnamPro(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 15),
                    Text(
                      'Cập nhật định dạng cho lời nhạc',
                      style: GoogleFonts.beVietnamPro(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 15),
                    Text(
                      'Phong cách',
                      style: GoogleFonts.beVietnamPro(
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
                        style: GoogleFonts.beVietnamPro(
                          fontSize: 15,
                          color: textColor,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Nhập phong cách,eg: ballad piano slow',
                          hintStyle: GoogleFonts.beVietnamPro(
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
                      'Lời Bài Hát Gốc',
                      style: GoogleFonts.beVietnamPro(
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
                        style: GoogleFonts.beVietnamPro(
                          fontSize: 15,
                          color: textColor,
                        ),
                        decoration: InputDecoration(
                          hintText:
                              'Nhập lời bài hát gốc,vd:\n'
                              'Yesterday\n'
                              'All my troubles',
                          hintStyle: GoogleFonts.beVietnamPro(
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
                      'Mô hình AI',
                      style: GoogleFonts.beVietnamPro(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 15),
                    DropdownButtonFormField<String>(
                      value: _selectedModel2, // Sửa từ _selectedModel thành _selectedModel2
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: 'Mô hình AI cho định dạng thời gian', // Nhãn rõ ràng hơn
                        labelStyle: TextStyle(
                          color: isDarkTheme ? highlightColor : Colors.grey[400],
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                            color: highlightColor,
                            width: 1.0,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                            color: highlightColor,
                            width: 2.0,
                          ),
                        ),
                        border: const OutlineInputBorder(),
                      ),
                      items: _models.map((String model) {
                        return DropdownMenuItem<String>(
                          value: model,
                          child: Text(model),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        if (newValue != null) {
                          setState(() {
                            _selectedModel2 = newValue; // Sửa thành _selectedModel2
                            _saveState();
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 15),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _addTimestampsToLyrics,
                        style: ElevatedButton.styleFrom(
                          side: const BorderSide(
                            color: Colors.black87,
                            width: 1.0,
                          ),
                          backgroundColor: const Color(0xFFADD8E6),
                          foregroundColor: Colors.black87,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Cập Nhật Định Dạng',
                          style: GoogleFonts.beVietnamPro(
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
            if (_generatedLyrics.isNotEmpty)
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side:
                      isDarkTheme
                          ? const BorderSide(
                            color: Color(0xFFADD8E6),
                            width: 1.5,
                          )
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
                                onPressed:
                                    _generatedLyrics.isNotEmpty
                                        ? _copyLyricsToClipboard
                                        : null,
                                tooltip: 'Copy lyrics',
                                color:
                                    _generatedLyrics.isNotEmpty
                                        ? null
                                        : Colors.grey,
                              ),
                              IconButton(
                                icon: const Icon(Icons.save),
                                onPressed:
                                    _generatedLyrics.isNotEmpty && !_isSaved
                                        ? _saveLyrics
                                        : null,
                                tooltip: 'Save lyrics',
                                color:
                                    _generatedLyrics.isNotEmpty && !_isSaved
                                        ? null
                                        : Colors.grey,
                              ),
                              IconButton(
                                icon: const Icon(Icons.cancel_outlined),
                                onPressed:
                                    _generatedLyrics.isNotEmpty
                                        ? _deleteLyrics
                                        : null,
                                tooltip: 'Delete lyrics',
                                color:
                                    _generatedLyrics.isNotEmpty
                                        ? null
                                        : Colors.grey,
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
            if (_isLoading && _generatedLyrics.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Color(0xFFADD8E6),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Đang tải...',
                        style: GoogleFonts.beVietnamPro(
                          fontSize: 16,
                          color: textColor,
                        ),
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
