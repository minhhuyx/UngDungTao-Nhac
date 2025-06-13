import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'musicplay_screen.dart';

Widget buildMusicCard(
  String? generatedAudioPath,
  Color cardColor,
  Color cardTextColor,
  TextEditingController textPromptController,
  BuildContext context,
  Function() onDelete,
) {
  bool isPlaying = false;
  final ValueNotifier<double> sliderValue = ValueNotifier<double>(0.0);
  final AudioPlayer audioPlayer = AudioPlayer();
  Duration? totalDuration;
  final highlightColor = const Color(0xFFADD8E6);
  bool isLiked = false;

  // Thiết lập AudioPlayer
  void _setupAudioPlayer() {
    // Lắng nghe thời lượng bài hát
    audioPlayer.onDurationChanged.listen((Duration duration) {
      totalDuration = duration;
    });

    // Lắng nghe vị trí phát nhạc
    audioPlayer.onPositionChanged.listen((Duration position) {
      if (totalDuration != null && totalDuration!.inSeconds > 0) {
        sliderValue.value = position.inSeconds / totalDuration!.inSeconds;
      }
    });

    // Khi bài hát kết thúc, đặt lại trạng thái
    audioPlayer.onPlayerComplete.listen((event) {
      sliderValue.value = 0.0;
      isPlaying = false;
    });
  }

  _setupAudioPlayer();

  return Padding(
    padding: const EdgeInsets.only(top: 10.0),
    child: StatefulBuilder(
      builder: (BuildContext context, StateSetter setState) {
        return Card(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: highlightColor, width: 1.5),
          ),
          color: cardColor.withOpacity(0.9),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(5.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(5.0, 2.0, 5.0, 2.0),
                  child: GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (context) => MusicPlayScreen(
                                generatedAudioPath: generatedAudioPath,
                                textPromptController: textPromptController,
                              ),
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Row(
                        children: [
                          Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              image: const DecorationImage(
                                image: AssetImage('assets/avatar2.png'),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          const SizedBox(width: 15),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  generatedAudioPath != null
                                      ? generatedAudioPath.split('/').last
                                      : 'No Audio',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: cardTextColor,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  'This Phone',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: cardTextColor.withOpacity(0.7),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          Row(
                            children: [
                              IconButton(
                                icon: Icon(
                                  Icons.favorite,
                                  color: isLiked ? Colors.red : Colors.grey,
                                  size: 20,
                                ),
                                onPressed: () {
                                  setState(() {
                                    isLiked = !isLiked;
                                  });
                                },
                                tooltip: isLiked ? 'Bỏ thích' : 'Thích',
                              ),
                              IconButton(
                                icon: Icon(
                                  isPlaying ? Icons.pause : Icons.play_arrow,
                                  color: highlightColor,
                                  size: 20,
                                ),
                                onPressed: () async {
                                  if (generatedAudioPath != null) {
                                    try {
                                      if (isPlaying) {
                                        await audioPlayer.pause();
                                      } else {
                                        await audioPlayer.play(
                                          DeviceFileSource(generatedAudioPath),
                                        );
                                      }
                                      setState(() {
                                        isPlaying = !isPlaying;
                                      });
                                    } catch (e) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text('Lỗi phát nhạc: $e'),
                                        ),
                                      );
                                    }
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Không có tệp âm thanh để phát',
                                        ),
                                      ),
                                    );
                                  }
                                },
                                tooltip: isPlaying ? 'Tạm dừng' : 'Phát',
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.close,
                                  color: Colors.red,
                                  size: 20,
                                ),
                                onPressed: () {
                                  audioPlayer.stop(); // Dừng phát trước khi xóa
                                  onDelete();
                                },
                                tooltip: 'Xóa tệp nhạc',
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 5.0),
                  child: ValueListenableBuilder<double>(
                    valueListenable: sliderValue,
                    builder: (context, value, child) {
                      return Slider(
                        value: value,
                        min: 0.0,
                        max: 1.0,
                        activeColor: highlightColor,
                        inactiveColor: Colors.grey[300],
                        onChanged: (newValue) {
                          if (totalDuration != null &&
                              generatedAudioPath != null) {
                            sliderValue.value = newValue;
                            final newPosition =
                                (newValue * totalDuration!.inSeconds).toInt();
                            audioPlayer.seek(Duration(seconds: newPosition));
                          }
                        },
                        onChangeEnd: (newValue) async {
                          if (isPlaying && generatedAudioPath != null) {
                            await audioPlayer.resume();
                          }
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

class LyricsHistoryManager {
  static const int maxLyrics = 5; // Giới hạn 5 lời bài hát

  Future<void> addLyricsToHistory({
    required String generatedLyrics,
    required String language,
    required String theme,
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
      if (snapshot.exists && snapshot.value is Map) {
        final lyricsEntries = Map<String, dynamic>.from(snapshot.value as Map);
        if (lyricsEntries.length >= maxLyrics) {
          final oldestKey = snapshot.children.first.key;
          await databaseRef.child(oldestKey!).remove();
        }
      }

      final newLyricsRef = databaseRef.push();
      final localTime = DateTime.now();
      await newLyricsRef.set({
        'generated_lyrics': generatedLyrics,
        'language': language,
        'theme': theme,
        'category': category,
        'created_at': ServerValue.timestamp,
      });

      final savedSnapshot = await newLyricsRef.get();
      if (savedSnapshot.exists && savedSnapshot.value is Map) {
        final savedData = Map<String, dynamic>.from(savedSnapshot.value as Map);
        final createdAt = savedData['created_at'] as int?;
        final deviceTime = localTime.millisecondsSinceEpoch;
        if (createdAt != null && (createdAt - deviceTime).abs() > 10000) {
          throw Exception('Chênh lệch thời gian lớn giữa thiết bị và server.');
        }
      }
    } catch (e) {
      print('Lỗi khi thêm lời bài hát vào lịch sử: $e');
      rethrow;
    }
  }
}

class GeneratedLyricsWidget extends StatelessWidget {
  final String generatedLyrics;
  final bool isSaved;
  final VoidCallback onCopy;
  final VoidCallback? onSave;
  final VoidCallback onDelete;
  final Color textColor;
  final Color highlightColor;

  const GeneratedLyricsWidget({
    Key? key,
    required this.generatedLyrics,
    required this.isSaved,
    required this.onCopy,
    required this.onSave,
    required this.onDelete,
    required this.textColor,
    required this.highlightColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side:
            isDarkTheme
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
                Text(
                  'Lời bài hát được tạo',
                  style: GoogleFonts.beVietnamPro(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.copy),
                      onPressed: generatedLyrics.isNotEmpty ? onCopy : null,
                      tooltip: 'Sao chép lời bài hát',
                      color:
                          generatedLyrics.isNotEmpty
                              ? highlightColor
                              : Colors.grey,
                    ),
                    IconButton(
                      icon: const Icon(Icons.save),
                      onPressed:
                          generatedLyrics.isNotEmpty &&
                                  !isSaved &&
                                  onSave != null
                              ? onSave
                              : null,
                      tooltip: 'Lưu lời bài hát',
                      color:
                          generatedLyrics.isNotEmpty && !isSaved
                              ? highlightColor
                              : Colors.grey,
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: generatedLyrics.isNotEmpty ? onDelete : null,
                      tooltip: 'Xóa lời bài hát',
                      color:
                          generatedLyrics.isNotEmpty
                              ? highlightColor
                              : Colors.grey,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 15),
            Text(generatedLyrics, style: const TextStyle(fontSize: 16)),
          ],
        ),
      ),
    );
  }
}

class BeatScreen extends StatefulWidget {
  const BeatScreen({Key? key}) : super(key: key);

  @override
  _BeatScreenState createState() => _BeatScreenState();
}

class _BeatScreenState extends State<BeatScreen> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  String? _audioPath;

  String _selectedLanguage = 'en';
  final _themeController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _songLyricsController = TextEditingController();
  String _selectedGenre = 'Custom';
  String _generatedLyrics = '';
  String _currentTheme = '';
  bool _isLoadingLyrics = false;
  bool _isLoadingSong = false;
  bool _isSaved = false;

  final LyricsHistoryManager _historyManager = LyricsHistoryManager();

  final List<String> _models = ['Phi-4', 'DeepSeek-V3-0324', 'gpt-4o'];
  String _selectedModel = 'gpt-4o';

  final Map<String, String> _genreDescriptions = {
    'Custom': '',
    'Modern Pop':
        'pop, synth, drums, guitar, 120 bpm, upbeat, catchy, vibrant, female vocals, polished vocals',
    'Rock':
        'rock, electric guitar, drums, bass, 130 bpm, energetic, rebellious, gritty, male vocals, raw vocals',
    'Hip Hop':
        'hip hop, 808 bass, hi-hats, synth, 90 bpm, bold, urban, intense, male vocals, rhythmic vocals',
    'Country':
        'country, acoustic guitar, steel guitar, fiddle, 100 bpm, heartfelt, rustic, warm, male vocals, twangy vocals',
    'EDM':
        'edm, synth, bass, kick drum, 128 bpm, euphoric, pulsating, energetic, instrumental',
    'Reggae':
        'reggae, guitar, bass, drums, 80 bpm, chill, soulful, positive, male vocals, smooth vocals',
    'Classical':
        'classical, orchestral, strings, piano, 60 bpm, elegant, emotive, timeless, instrumental',
    'Jazz':
        'jazz, saxophone, piano, double bass, 110 bpm, smooth, improvisational, soulful, male vocals, crooning vocals',
    'Metal':
        'metal, electric guitar, double kick drum, bass, 160 bpm, aggressive, intense, heavy, male vocals, screamed vocals',
    'R&B':
        'r&b, synth, bass, drums, 85 bpm, sultry, groovy, romantic, female vocals, silky vocals',
  };

  final Map<String, String> _lyricsCache = {};

  @override
  void initState() {
    super.initState();
    _loadSavedState();
  }

  Future<void> _loadSavedState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _generatedLyrics = prefs.getString('beat_generatedLyrics') ?? '';
        _currentTheme = prefs.getString('beat_currentTheme') ?? '';
        _selectedLanguage = prefs.getString('beat_selectedLanguage') ?? 'en';
        _selectedModel = prefs.getString('beat_selectedModel') ?? 'gpt-4o';
        _isSaved = prefs.getBool('beat_isSaved') ?? false;
        _selectedGenre = prefs.getString('beat_selectedGenre') ?? 'Custom';
        _audioPath = prefs.getString('generated_song_path');
        _descriptionController.text = _genreDescriptions[_selectedGenre] ?? '';
        // Kiểm tra xem file âm thanh có tồn tại không
        if (_audioPath != null) {
          final file = File(_audioPath!);
          if (!file.existsSync()) {
            _audioPath = null; // Xóa _audioPath nếu file không tồn tại
            prefs.remove('generated_song_path');
          }
        }
      });
    } catch (e) {
      print('Lỗi khi tải trạng thái: $e');
    }
  }

  Future<void> _saveState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('beat_generatedLyrics', _generatedLyrics);
      await prefs.setString('beat_currentTheme', _currentTheme);
      await prefs.setString('beat_selectedLanguage', _selectedLanguage);
      await prefs.setString('beat_selectedModel', _selectedModel);
      await prefs.setBool('beat_isSaved', _isSaved);
      await prefs.setString('beat_selectedGenre', _selectedGenre);
    } catch (e) {
      print('Lỗi khi lưu trạng thái: $e');
    }
  }

  Future<void> _clearLocalLyrics() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('beat_generatedLyrics');
      await prefs.remove('beat_currentTheme');
      await prefs.setBool('beat_isSaved', false);
      setState(() {
        _generatedLyrics = '';
        _currentTheme = '';
        _isSaved = false;
        _themeController.clear();
        _songLyricsController.clear();
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Đã xóa lời bài hát!')));
    } catch (e) {
      print('Lỗi khi xóa trạng thái: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Lỗi khi xóa: $e')));
    }
  }

  Future<void> _generateLyricsFromTheme() async {
    final theme = _themeController.text.trim();

    if (theme.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Vui lòng nhập chủ đề')));
      return;
    }

    setState(() {
      _isLoadingLyrics = true; // Bật loading cho tạo lời nhạc
      _generatedLyrics = '';
      _isSaved = false;
    });

    final cacheKey = '$theme|$_selectedLanguage|$_selectedModel';
    if (_lyricsCache.containsKey(cacheKey)) {
      setState(() {
        _generatedLyrics = _lyricsCache[cacheKey]!;
        _currentTheme = theme;
        _themeController.clear();
        _isLoadingLyrics = false; // Tắt loading
      });
      await _saveState();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lời bài hát được lấy từ bộ nhớ cache!')),
      );
      return;
    }

    try {
      final String baseApiUrl = dotenv.env['baseApiUrl_Lyrics'] ?? '';
      final String apiKey = dotenv.env['apiKey_Lyrics'] ?? '';
      final String apiUrl = '$baseApiUrl/chat/completions';

      if (baseApiUrl.isEmpty || apiKey.isEmpty) {
        throw Exception('Thiếu URL API hoặc khóa API');
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
                  'Write a high-quality song based on the theme "$theme".\n'
                  'Language: ${_selectedLanguage == 'en' ? 'English' : 'Chinese'}.\n'
                  'Structure:\n'
                  '- At least 3 verses ([verse]), 1–2 choruses ([chorus]), and 1 bridge ([bridge]).\n'
                  '- Format the lyrics with the following structure:\n'
                  '  [verse]\n'
                  '  [Lines of lyrics with vivid imagery and natural rhyme]\n'
                  '  [verse]\n'
                  '  [Lines of lyrics continuing, maintaining emotion and rhythm]\n'
                  '  [chorus]\n'
                  '  [Powerful, memorable chorus lines that create a highlight]\n'
                  '  [verse]\n'
                  '  [Lines of lyrics, developing the story or emotion]\n'
                  '  [bridge]\n'
                  '  [Bridge lines, shifting rhythm or emotion, adding depth]\n'
                  '  [chorus]\n'
                  '  [Repeat or vary the chorus].\n'
                  'Duration: ~3 minutes (~45–60 lines, each verse or chorus approximately 4–6 lines).\n'
                  'Use vivid imagery, emotionally rich language, and natural rhyme, suitable for the "$theme".\n'
                  'Ensure the lyrics are cohesive, developing the story or emotion from start to finish.',
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
          _themeController.clear();
          _isLoadingLyrics = false; // Tắt loading
          _lyricsCache[cacheKey] = generatedLyrics;
        });
        await _saveState();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Lời bài hát đã được tạo!')),
        );
      } else {
        final errorData = jsonDecode(utf8.decode(response.bodyBytes));
        throw Exception(
          'Không thể tạo lời bài hát: ${errorData['error']?['message'] ?? response.statusCode}',
        );
      }
    } catch (e) {
      setState(() {
        _isLoadingLyrics = false; // Tắt loading khi lỗi
        _generatedLyrics = '';
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
    }
  }

  Future<void> _generateSong() async {
    final description = _descriptionController.text.trim();
    final lyrics = _songLyricsController.text.trim();

    if (description.isEmpty && lyrics.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập mô tả hoặc lời bài hát')),
      );
      return;
    }

    // Xóa bài hát cục bộ hiện tại nếu tồn tại
    if (_audioPath != null) {
      try {
        final file = File(_audioPath!);
        if (await file.exists()) {
          await file.delete();
        }
        setState(() {
          _audioPath = null;
        });
        await _saveState();
      } catch (e) {
        print('Lỗi khi xóa bài hát cũ: $e');
      }
    }

    setState(() {
      _isLoadingSong = true; // Bật loading cho tạo bài hát
    });

    try {
      final String baseApiUrl = dotenv.env['baseApiUrl_Song'] ?? '';
      final String apiUrl = '$baseApiUrl/infer';

      if (baseApiUrl.isEmpty) {
        throw Exception('Thiếu URL API cho bài hát');
      }

      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: jsonEncode({'prompt': description, 'lyrics': lyrics}),
      );

      if (response.statusCode == 200) {
        final directory = await getTemporaryDirectory();
        final prefs = await SharedPreferences.getInstance();
        int counter = (prefs.getInt('song_counter') ?? 0) + 1;
        final filePath =
            '${directory.path}/song_${counter.toString().padLeft(2, '0')}.mp3';
        final file = File(filePath);

        await file.writeAsBytes(response.bodyBytes); // Sử dụng writeAsBytes
        await prefs.setInt('song_counter', counter);
        await prefs.setString('generated_song_path', filePath);

        setState(() {
          _audioPath = filePath;
          _isLoadingSong = false; // Tắt loading
        });
        await _saveState();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Bài hát đã được tạo!')));
      } else {
        final errorData = jsonDecode(utf8.decode(response.bodyBytes));
        throw Exception(
          'Không thể tạo bài hát: ${errorData['error'] ?? response.statusCode}',
        );
      }
    } catch (e) {
      setState(() {
        _isLoadingSong = false; // Tắt loading khi lỗi
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
    }
  }

  Future<void> _playAudio() async {
    if (_audioPath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không có tệp âm thanh để phát')),
      );
      return;
    }

    try {
      await _audioPlayer.play(DeviceFileSource(_audioPath!));
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Đang phát âm thanh')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Lỗi khi phát âm thanh: $e')));
    }
  }

  Future<void> _saveLyrics() async {
    try {
      await _historyManager.addLyricsToHistory(
        generatedLyrics: _generatedLyrics,
        language: _selectedLanguage,
        theme: _currentTheme,
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
    ).showSnackBar(const SnackBar(content: Text('Đã sao chép lời bài hát!')));
  }

  Future<void> _deleteAudio() async {
    if (_audioPath != null) {
      try {
        final file = File(_audioPath!);
        if (await file.exists()) {
          await file.delete();
        }
        setState(() {
          _audioPath = null;
        });
        await _saveState();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Đã xóa tệp nhạc!')));
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Lỗi khi xóa: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;
    final highlightColor = const Color(0xFFADD8E6);
    final textColor = isDarkTheme ? Colors.white : Colors.black87;
    final selectedValue = _selectedGenre;

    return Scaffold(
      appBar: AppBar(
        title: const Text('ACE-STEP AI'),
        backgroundColor: highlightColor,
        actions: [
          Builder(
            builder: (context) {
              final double appBarHeight = AppBar().preferredSize.height;
              final double imageHeight = appBarHeight * 0.8;
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
        padding: const EdgeInsets.all(10.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                color: isDarkTheme ? Colors.black : Colors.white,
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: highlightColor, width: 2.0),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tạo Lời Nhạc:',
                        style: GoogleFonts.beVietnamPro(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 15),
                      Text(
                        'Chủ đề và Phong Cách',
                        style: GoogleFonts.beVietnamPro(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _themeController,
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 16,
                          fontWeight: FontWeight.normal,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Nhập phong cách và thể loại của bạn',
                          labelStyle: TextStyle(
                            color:
                                isDarkTheme ? highlightColor : Colors.grey[400],
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          prefixIcon: const Icon(Icons.create),
                          filled: true,
                          fillColor: Colors.white,
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
                      ),
                      const SizedBox(height: 15),
                      Text(
                        'Ngôn ngữ',
                        style: GoogleFonts.beVietnamPro(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 10),
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
                                    activeColor: highlightColor,
                                    fillColor:
                                        MaterialStateProperty.resolveWith<
                                          Color
                                        >(
                                          (states) =>
                                              states.contains(
                                                    MaterialState.selected,
                                                  )
                                                  ? highlightColor
                                                  : isDarkTheme
                                                  ? Colors.white70
                                                  : Colors.black54,
                                        ),
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
                                    color: textColor,
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
                                    activeColor: highlightColor,
                                    fillColor:
                                        MaterialStateProperty.resolveWith<
                                          Color
                                        >(
                                          (states) =>
                                              states.contains(
                                                    MaterialState.selected,
                                                  )
                                                  ? highlightColor
                                                  : isDarkTheme
                                                  ? Colors.white70
                                                  : Colors.black54,
                                        ),
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
                                    color: textColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 15),
                      Text(
                        'Mô hình AI',
                        style: GoogleFonts.beVietnamPro(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 10),
                      DropdownButton<String>(
                        value: _selectedModel,
                        isExpanded: true,
                        hint: const Text('Chọn mô hình AI'),
                        items:
                            _models.map((String model) {
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
                          onPressed:
                              _isLoadingLyrics
                                  ? null
                                  : _generateLyricsFromTheme,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: highlightColor,
                            foregroundColor: Colors.black,
                            side: const BorderSide(
                              color: Colors.black,
                              width: 1.0,
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            'Tạo Lời Bài Hát',
                            style: GoogleFonts.beVietnamPro(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (_isLoadingLyrics && _generatedLyrics.isEmpty)
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
                                  'Đang tạo lời nhạc...',
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
              ),
              if (_generatedLyrics.isNotEmpty) ...[
                const SizedBox(height: 15),
                GeneratedLyricsWidget(
                  generatedLyrics: _generatedLyrics,
                  isSaved: _isSaved,
                  onCopy: _copyLyricsToClipboard,
                  onSave: _saveLyrics,
                  onDelete: _clearLocalLyrics,
                  textColor: textColor,
                  highlightColor: highlightColor,
                ),
              ],
              const SizedBox(height: 15),
              Card(
                color: isDarkTheme ? Colors.black : Colors.white,
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: highlightColor, width: 2.0),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tạo Bài Hát:',
                        style: GoogleFonts.beVietnamPro(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 15),
                      Row(
                        children: [
                          Expanded(
                            flex: 1,
                            child: DropdownButtonFormField<String>(
                              value: selectedValue,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Chọn thể loại',
                                enabledBorder: OutlineInputBorder(
                                  borderSide: BorderSide(
                                    color: Color(0xFFADD8E6),
                                    width: 1.0,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderSide: BorderSide(
                                    color: Color(0xFFADD8E6),
                                    width: 2.5,
                                  ),
                                ),
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                              ),
                              items:
                                  _genreDescriptions.keys.map((String value) {
                                    return DropdownMenuItem<String>(
                                      value: value,
                                      child: Text(value),
                                    );
                                  }).toList(),
                              onChanged: (String? newValue) {
                                if (newValue != null) {
                                  setState(() {
                                    _selectedGenre = newValue;
                                    _descriptionController.text =
                                        _genreDescriptions[newValue] ?? '';
                                    _saveState();
                                  });
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: TextField(
                              style: const TextStyle(
                                color: Colors.black,
                                fontSize: 16,
                                fontWeight: FontWeight.normal,
                              ),
                              controller: _descriptionController,
                              maxLines: 2,
                              decoration: InputDecoration(
                                labelText: 'Nhập mô tả của bạn',
                                labelStyle: TextStyle(
                                  color:
                                      isDarkTheme
                                          ? highlightColor
                                          : Colors.grey[400],
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                                prefixIcon: const Icon(Icons.music_note),
                                filled: true,
                                fillColor: Colors.white,
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
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 15),
                      TextField(
                        maxLines: 5,
                        controller: _songLyricsController,
                        style: GoogleFonts.beVietnamPro(
                          fontSize: 18,
                          color: Colors.black,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Nhập lời bài hát của bạn',
                          hintStyle: GoogleFonts.beVietnamPro(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color:
                                isDarkTheme ? highlightColor : Colors.grey[400],
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                              color: highlightColor,
                              width: 1.0,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                              color: highlightColor,
                              width: 3.0,
                            ),
                          ),
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 15),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isLoadingSong ? null : _generateSong,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: highlightColor,
                            foregroundColor: Colors.black,
                            side: const BorderSide(
                              color: Colors.black,
                              width: 1.0,
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            'Tạo bài hát',
                            style: GoogleFonts.beVietnamPro(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (_isLoadingSong)
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
                          'Đang tạo bài hát...',
                          style: GoogleFonts.beVietnamPro(
                            fontSize: 16,
                            color: textColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              if (_audioPath != null)
                buildMusicCard(
                  _audioPath,
                  isDarkTheme ? Colors.black : Colors.white,
                  textColor,
                  _descriptionController,
                  context,
                  _deleteAudio,
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _themeController.dispose();
    _descriptionController.dispose();
    _songLyricsController.dispose();
    super.dispose();
  }
}
