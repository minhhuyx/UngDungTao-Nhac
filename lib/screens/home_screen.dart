import 'dart:convert';
import 'dart:io';
import 'package:audioplayers/audioplayers.dart' as audio;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'musicplay_screen.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

// Widget buildMusicCard không thay đổi
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
  final audio.AudioPlayer audioPlayer = audio.AudioPlayer();
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
                                  style: GoogleFonts.beVietnamPro(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: cardTextColor,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  'This Phone',
                                  style: GoogleFonts.beVietnamPro(
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
                                          audio.DeviceFileSource(
                                            generatedAudioPath,
                                          ),
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

class AppConstants {
  static const int maxSongs = 10;
  static const List<String> supportedFormats = ['mp3', 'wav', 'ogg'];
  static final String apiBaseUrl = dotenv.env['API_BASE_URL'] ?? '';
}

class HistoryManager {
  Future<void> addSongToHistory({
    required String themeName,
    required String title,
    required String lyrics,
    required File songFile,
    required String? fileUrl,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('Người dùng chưa đăng nhập.');
      }
      final userId = user.uid;

      final databaseRef = FirebaseDatabase.instance.ref(
        'lyrics_history/$userId',
      );
      final newSongRef = databaseRef.push();

      final songData = {
        'id': newSongRef.key,
        'title': title,
        'theme_name': themeName,
        'lyrics': lyrics,
        'file_url': fileUrl ?? '',
        'created_at': ServerValue.timestamp,
      };

      await newSongRef.set(songData);
    } catch (e) {
      throw Exception('Lỗi khi lưu bài hát: $e');
    }
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

enum PromptType { none, audio, text }

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _lyricsController = TextEditingController();
  final TextEditingController _textPromptController = TextEditingController();
  int _selectedDuration = 95;
  String? _selectedAudioPath;
  String? _generatedAudioPath;
  bool _isGenerating = false;
  PromptType _selectedPrompt = PromptType.none;
  final ScrollController _scrollController = ScrollController();
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  bool _isRecording = false;
  final HistoryManager _historyManager = HistoryManager();
  List<Map<String, dynamic>> _historySongs = [];
  final audio.AudioPlayer _audioPlayer = audio.AudioPlayer();
  bool _isPlaying = false;

  Future<void> _deleteLocalAudio() async {
    if (_generatedAudioPath != null) {
      try {
        final file = File(_generatedAudioPath!);
        if (await file.exists()) {
          await file.delete();
        }
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('generated_audio_path');
        setState(() {
          _generatedAudioPath = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã xóa tệp nhạc thành công')),
        );
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Lỗi khi xóa tệp: $e')));
      }
    }
  }

  Future<void> _pickAudioFile() async {
    if (_textPromptController.text.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Vui lòng xóa nội dung text prompt trước khi chọn file âm thanh.',
          ),
        ),
      );
      return;
    }
    try {
      const XTypeGroup typeGroup = XTypeGroup(
        label: 'audio',
        extensions: AppConstants.supportedFormats,
      );
      final XFile? file = await openFile(acceptedTypeGroups: [typeGroup]);
      if (file != null) {
        final fileSize = await File(file.path).length();
        if (fileSize > 10 * 1024 * 1024) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('File âm thanh quá lớn (tối đa 10MB).'),
            ),
          );
          return;
        }
        final extension = file.path.split('.').last.toLowerCase();
        if (!AppConstants.supportedFormats.contains(extension)) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Định dạng không hỗ trợ. Vui lòng chọn ${AppConstants.supportedFormats.join(", ")}',
              ),
            ),
          );
          return;
        }
        if (!await _isValidAudioDuration(file.path)) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Tệp âm thanh không hợp lệ hoặc quá ngắn (<10 giây).',
              ),
            ),
          );
          return;
        }
        await _resetAudioPlayer();
        _resetOtherPrompts(PromptType.audio);
        setState(() {
          _selectedAudioPath = file.path;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Lỗi khi chọn file âm thanh: $e')));
    }
  }

  Future<bool> _isValidAudioDuration(String filePath) async {
    final player = audio.AudioPlayer();
    try {
      await player.setSource(audio.DeviceFileSource(filePath));
      final duration = await player.getDuration();
      await player.dispose();
      return duration != null && duration.inSeconds >= 1;
    } catch (e) {
      return false;
    }
  }

  Future<bool> _isConnected() async {
    final connectivity = Connectivity();
    final connectivityResult = await connectivity.checkConnectivity();
    if (connectivityResult == ConnectivityResult.none) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Không có kết nối mạng. Vui lòng kiểm tra lại.'),
        ),
      );
      return false;
    }
    return true;
  }

  Future<void> _toggleRecording() async {
    if (_textPromptController.text.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng xóa nội dung text prompt trước khi ghi âm.'),
        ),
      );
      return;
    }
    try {
      if (_isRecording) {
        final path = await _recorder.stopRecorder();
        if (path != null) {
          final file = File(path);
          final fileSize = await file.length();
          if (fileSize > 10 * 1024 * 1024) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('File ghi âm quá lớn (tối đa 10MB).'),
              ),
            );
            await file.delete();
            return;
          }
          if (!await _isValidAudioDuration(path)) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Tệp âm thanh phải dài ít nhất 10 giây'),
              ),
            );
            await file.delete();
            return;
          }
          setState(() {
            _isRecording = false;
            _selectedAudioPath = path;
          });
        }
      } else {
        var status = await Permission.microphone.request();
        if (status.isGranted) {
          final directory = await getTemporaryDirectory();
          final filePath = '${directory.path}/recorded_audio.aac';
          await _recorder.startRecorder(toFile: filePath);
          Future.delayed(Duration(seconds: 10), () async {
            if (_isRecording) {
              await _toggleRecording();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Ghi âm đã đạt giới hạn 10 giây')),
              );
            }
          });
          await _resetAudioPlayer();
          _resetOtherPrompts(PromptType.audio);
          setState(() {
            _isRecording = true;
            _selectedAudioPath = null;
          });
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Quyền microphone bị từ chối.')),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Lỗi khi ghi âm: $e')));
    }
  }

  Future<void> _togglePlayPause() async {
    if (_selectedAudioPath == null ||
        !await File(_selectedAudioPath!).exists()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tệp âm thanh không tồn tại hoặc không hợp lệ'),
        ),
      );
      setState(() {
        _selectedAudioPath = null;
        _isPlaying = false;
      });
      return;
    }
    try {
      if (_audioPlayer.state == audio.PlayerState.playing) {
        await _audioPlayer.pause();
        setState(() {
          _isPlaying = false;
        });
      } else {
        await _audioPlayer.play(audio.DeviceFileSource(_selectedAudioPath!));
        setState(() {
          _isPlaying = true;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Lỗi khi phát âm thanh: $e')));
      await _resetAudioPlayer();
    }
  }

  Future<void> _resetAudioPlayer() async {
    if (_audioPlayer.state != audio.PlayerState.stopped) {
      await _audioPlayer.stop();
    }
    setState(() {
      _isPlaying = false;
    });
  }

  void _resetOtherPrompts(PromptType newPrompt) {
    setState(() {
      _selectedPrompt = newPrompt;
      if (newPrompt == PromptType.audio) {
        _textPromptController.clear();
      } else if (newPrompt == PromptType.text) {
        _selectedAudioPath = null;
        _isRecording = false;
      }
    });
  }

  Future<void> _cleanOldFiles() async {
    final directory = await getTemporaryDirectory();
    final files =
        directory
            .listSync()
            .where((file) => file.path.endsWith('.mp3'))
            .map((file) => File(file.path))
            .toList();
    if (files.length >= AppConstants.maxSongs) {
      files.sort(
        (a, b) => a.lastModifiedSync().compareTo(b.lastModifiedSync()),
      );
      for (var file in files.sublist(
        0,
        files.length - AppConstants.maxSongs + 1,
      )) {
        await file.delete();
      }
    }
  }

  Future<void> _generateMusic() async {
    if (_lyricsController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập lời bài hát!')),
      );
      return;
    }
    if (!_isValidLyricsFormat(_lyricsController.text)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Lời bài hát không đúng định dạng [mm:ss.xx] Lyric content',
          ),
        ),
      );
      return;
    }
    if (_selectedPrompt == PromptType.none) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng chọn Text Prompt hoặc Audio Prompt!'),
        ),
      );
      return;
    }
    if (_selectedPrompt == PromptType.audio &&
        (_selectedAudioPath == null ||
            !File(_selectedAudioPath!).existsSync())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng chọn hoặc ghi âm một file âm thanh!'),
        ),
      );
      return;
    }
    if (!await _isConnected()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Không có kết nối mạng. Vui lòng kiểm tra lại.'),
        ),
      );
      return;
    }

    setState(() {
      _isGenerating = true;
    });

    try {
      final String ngrokUrl = AppConstants.apiBaseUrl;
      final String generateUrl = '$ngrokUrl/generate_music';
      var request = http.MultipartRequest('POST', Uri.parse(generateUrl));
      request.fields['lyrics'] = _lyricsController.text.trim();
      request.fields['prompt_type'] =
          _selectedPrompt == PromptType.text ? 'text' : 'audio';
      request.fields['audio_length'] = _selectedDuration.toString();

      if (_selectedPrompt == PromptType.text) {
        if (_textPromptController.text.trim().isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Vui lòng nhập text prompt!')),
          );
          setState(() {
            _isGenerating = false;
          });
          return;
        }
        request.fields['ref_prompt'] = _textPromptController.text.trim();
      } else {
        request.files.add(
          await http.MultipartFile.fromPath('file', _selectedAudioPath!),
        );
      }

      final response = await request.send();
      if (response.statusCode == 200) {
        final bytes = await response.stream.toBytes();
        if (bytes.isEmpty) throw Exception('Dữ liệu MP3 từ server trống');

        await _cleanOldFiles(); // Xóa file cũ trước khi lưu file mới
        final directory = await getTemporaryDirectory();
        final prefs = await SharedPreferences.getInstance();
        int counter = (prefs.getInt('music_counter') ?? 0) + 1;
        final filePath =
            '${directory.path}/music_${counter.toString().padLeft(2, '0')}.mp3';
        final file = File(filePath);
        await file.writeAsBytes(bytes);
        await prefs.setInt('music_counter', counter);
        await prefs.setString('generated_audio_path', filePath);

        await _resetAudioPlayer();
        setState(() {
          _generatedAudioPath = filePath;
          _selectedAudioPath = null;
          _lyricsController.clear();
          _textPromptController.clear();
          _selectedPrompt = PromptType.none;
        });

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Tạo nhạc thành công!')));
      } else {
        final responseBody = await response.stream.bytesToString();
        String errorMessage = 'Lỗi từ server: ${response.statusCode}';
        try {
          final errorJson = jsonDecode(responseBody);
          errorMessage += ' - ${errorJson['message'] ?? responseBody}';
        } catch (_) {}
        throw Exception(errorMessage);
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Lỗi khi tạo nhạc: $e')));
      setState(() {
        _generatedAudioPath = null;
      });
    } finally {
      setState(() {
        _isGenerating = false;
      });
    }
  }

  bool _isValidLyricsFormat(String lyrics) {
    final lines = lyrics.trim().split('\n');
    final regex = RegExp(r'^\[([0-5][0-9]):([0-5][0-9])\.(\d{2})\]\s*.+$');
    return lines.every((line) {
      if (line.trim().isEmpty) return true;
      final match = regex.firstMatch(line.trim());
      return match != null;
    });
  }

  Future<void> _initRecorder() async {
    try {
      if (!_recorder.isStopped) {
        await _recorder.closeRecorder();
      }
      await _recorder.openRecorder();
      final status = await Permission.microphone.request();
      if (status != PermissionStatus.granted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vui lòng cấp quyền microphone để ghi âm'),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Lỗi khi khởi tạo recorder: $e')));
    }
  }

  Future<void> _loadGeneratedAudioPath() async {
    final prefs = await SharedPreferences.getInstance();
    final savedPath = prefs.getString('generated_audio_path');
    if (savedPath != null) {
      try {
        final file = File(savedPath);
        if (await file.exists() && await _isValidAudioDuration(savedPath)) {
          final lastModified = await file.lastModified();
          if (DateTime.now().difference(lastModified).inHours < 24) {
            setState(() {
              _generatedAudioPath = savedPath;
            });
            return;
          }
        }
        await prefs.remove('generated_audio_path');
        if (await file.exists()) {
          await file.delete();
        }
      } catch (e) {
        await prefs.remove('generated_audio_path');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi khi tải tệp âm thanh đã lưu: $e')),
        );
      }
    }
  }

  Future<void> _loadHistorySongs() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng đăng nhập để xem lịch sử')),
      );
      // Navigator.pushNamed(context, '/login'); // Tùy chọn: chuyển hướng đến màn hình đăng nhập
      return;
    }
    final userId = user.uid;

    try {
      final databaseRef = FirebaseDatabase.instance.ref(
        'lyrics_history/$userId',
      );
      final snapshot =
          await databaseRef.orderByChild('created_at').limitToLast(50).once();
      final data = snapshot.snapshot.value;
      final List<Map<String, dynamic>> loadedSongs = [];
      if (data != null && data is Map) {
        data.forEach((key, value) {
          if (value is Map) {
            loadedSongs.add({
              'id': key,
              'title': value['title']?.toString() ?? 'Unknown Title',
              'theme_name': value['theme_name']?.toString() ?? 'Unknown Style',
              'file_url': value['file_url']?.toString() ?? '',
              'created_at':
                  value['created_at'] is int
                      ? value['created_at']
                      : DateTime.now().millisecondsSinceEpoch,
            });
          }
        });
        loadedSongs.sort(
          (a, b) => (b['created_at'] as int).compareTo(a['created_at'] as int),
        );
      }

      setState(() {
        _historySongs = loadedSongs;
      });
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Lỗi khi truy cập lịch sử: $e')));
    }
  }

  @override
  void initState() {
    super.initState();
    _initRecorder();
    _loadGeneratedAudioPath();
    _loadHistorySongs();
    _audioPlayer.onPlayerStateChanged.listen((state) {
      setState(() {
        _isPlaying = state == audio.PlayerState.playing;
      });
    });
    _textPromptController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _recorder.closeRecorder();
    _audioPlayer.stop();
    _audioPlayer.dispose();
    _lyricsController.dispose();
    _textPromptController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDarkTheme ? Colors.white : Colors.black87;
    final cardColor = Colors.white;
    final highlightColor = const Color(0xFFADD8E6);
    final cardTextColor = Colors.black87;

    return Scaffold(
      appBar: AppBar(
        title: const Text('DIFFRHYTHM AI'),
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
        padding: const EdgeInsets.all(16.0),
        controller: _scrollController,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Lời Bài Hát:',
              style: GoogleFonts.beVietnamPro(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: _lyricsController,
              maxLines: 5,
              style: GoogleFonts.beVietnamPro(
                fontSize: 18,
                color: Colors.black,
              ),
              decoration: InputDecoration(
                hintText: 'Nhập lời bài hát của bạn tại đây...',
                hintStyle: GoogleFonts.beVietnamPro(
                  fontSize: 18,
                  color: isDarkTheme ? Colors.black : Colors.black,
                ),
                filled: true,
                fillColor: isDarkTheme ? Colors.white : Colors.white,
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: highlightColor, width: 1.0),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: highlightColor, width: 3.0),
                ),
              ),
            ),
            const SizedBox(height: 15),
            Card(
              color: highlightColor,
              elevation: 6,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              child: ExpansionTile(
                title: Text(
                  'Hướng Dẫn',
                  style: GoogleFonts.beVietnamPro(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: cardTextColor,
                  ),
                ),
                collapsedBackgroundColor: highlightColor,
                shape: const Border(),
                collapsedShape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(15.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '1. Lyrics Format Requirements\n'
                          'Each line must follow: [mm:ss.xx] Lyric content\n'
                          'Example of valid format:',
                          style: GoogleFonts.beVietnamPro(
                            fontSize: 15,
                            color: cardTextColor,
                          ),
                        ),
                        Card(
                          elevation: 5,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(0),
                          ),
                          color: cardColor,
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '[00:10.00] Moonlight spills through broken blinds',
                                  style: GoogleFonts.beVietnamPro(
                                    fontSize: 15,
                                    color: cardTextColor,
                                  ),
                                ),
                                Text(
                                  '[00:13.20] Your shadow dances on the dashboard shrine',
                                  style: GoogleFonts.beVietnamPro(
                                    fontSize: 15,
                                    color: cardTextColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Text(
                          '2. Audio Prompt Requirements\n'
                          'Reference audio should be ≥ 1 second, audio >10 seconds will be randomly clipped into 10 seconds\n'
                          'For optimal results, the 10-second clips should be carefully selected\n'
                          'Shorter clips may lead to incoherent generation',
                          style: GoogleFonts.beVietnamPro(
                            fontSize: 15,
                            color: cardTextColor,
                          ),
                        ),
                        Text(
                          '3. Supported Languages\n'
                          'Chinese and English\n'
                          'More languages coming soon',
                          style: GoogleFonts.beVietnamPro(
                            fontSize: 15,
                            color: cardTextColor,
                          ),
                        ),
                        Text(
                          '4. Others\n'
                          'If loading audio result is slow, you can select Output Format as mp3 in Advanced Settings.',
                          style: GoogleFonts.beVietnamPro(
                            fontSize: 15,
                            color: cardTextColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 15),
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(color: highlightColor, width: 1.5),
              ),
              color: cardColor,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Text(
                      'Thời Lượng',
                      style: GoogleFonts.beVietnamPro(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: cardTextColor,
                      ),
                    ),
                    const SizedBox(height: 15),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        Expanded(
                          child: RadioListTile<int>(
                            title: Text(
                              '95s',
                              style: GoogleFonts.beVietnamPro(
                                fontSize: 20,
                                color: cardTextColor,
                              ),
                            ),
                            value: 95,
                            groupValue: _selectedDuration,
                            activeColor: highlightColor,
                            onChanged: (int? value) {
                              setState(() {
                                _selectedDuration = value!;
                              });
                            },
                          ),
                        ),
                        Expanded(
                          child: RadioListTile<int>(
                            title: Text(
                              '285s',
                              style: GoogleFonts.beVietnamPro(
                                fontSize: 20,
                                color: Colors.grey, // Hiển thị như bị disable
                              ),
                            ),
                            value: 285,
                            groupValue: _selectedDuration,
                            activeColor: Colors.grey,
                            onChanged: (int? value) {
                              // Không cập nhật state, chỉ hiện thông báo
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Tính năng đang phát triển'),
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 15),
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: highlightColor, width: 1.5),
              ),
              color: cardColor, // Giữ màu trắng cố định
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Mô Tả Âm Thanh',
                      style: GoogleFonts.beVietnamPro(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: cardTextColor,
                      ),
                    ),
                    const SizedBox(height: 15),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed:
                                _textPromptController.text.isNotEmpty ||
                                        _isRecording
                                    ? null
                                    : () {
                                      setState(() {
                                        _selectedPrompt = PromptType.audio;
                                      });
                                      _pickAudioFile();
                                    },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: highlightColor,
                              foregroundColor: cardTextColor,
                              side: BorderSide(
                                color: cardTextColor,
                                width: 1.0,
                              ),
                              disabledBackgroundColor: Colors.grey[300],
                            ),
                            child: Text(
                              'Tải âm thanh',
                              style: GoogleFonts.beVietnamPro(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: cardTextColor,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: ElevatedButton(
                            onPressed:
                                _textPromptController.text.isNotEmpty
                                    ? null
                                    : _toggleRecording,
                            style: ElevatedButton.styleFrom(
                              side: BorderSide(
                                color: cardTextColor,
                                width: 1.0,
                              ),
                              backgroundColor:
                                  _isRecording ? Colors.red : highlightColor,
                              foregroundColor: cardTextColor,
                              disabledBackgroundColor: Colors.grey[300],
                            ),
                            child: Text(
                              _isRecording ? 'Dừng ghi âm' : 'Ghi âm',
                              style: GoogleFonts.beVietnamPro(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: cardTextColor,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ), // Thêm dấu phẩy ở đây
                  ],
                ),
              ),
            ),
            if (_selectedAudioPath != null)
              Padding(
                padding: const EdgeInsets.only(top: 20.0),
                child: Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  color: cardColor,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        IconButton(
                          icon: Icon(
                            _isPlaying ? Icons.pause : Icons.play_arrow,
                            color: Colors.blue,
                          ),
                          onPressed: _togglePlayPause,
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: Text(
                            "File: ${_selectedAudioPath!.split('/').last}",
                            style: TextStyle(
                              fontSize: 16,
                              color: cardTextColor,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 15),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () {
                            setState(() {
                              _selectedAudioPath = null;
                              _isPlaying = false;
                            });
                            if (_audioPlayer.state !=
                                audio.PlayerState.stopped) {
                              _audioPlayer.stop();
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 15),
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: highlightColor, width: 1.0),
              ),
              color: Colors.white, // Giữ màu nền trắng cố định
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Mô Tả Phong Cách',
                      style: GoogleFonts.beVietnamPro(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: cardTextColor,
                      ),
                    ),
                    const SizedBox(height: 15),
                    TextField(
                      controller: _textPromptController,
                      enabled:
                          _selectedAudioPath == null &&
                          !_isRecording, // Vô hiệu hóa khi có file âm thanh hoặc đang ghi âm
                      onTap: () {
                        if (_selectedAudioPath != null || _isRecording) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Vui lòng hủy file âm thanh hoặc dừng ghi âm trước khi nhập text prompt.',
                              ),
                            ),
                          );
                          return;
                        }
                        setState(() {
                          _selectedPrompt = PromptType.text;
                        });
                      },
                      style: GoogleFonts.beVietnamPro(
                        fontSize: 16,
                        color: Colors.black,
                      ),
                      decoration: InputDecoration(
                        prefixIcon: Icon(Icons.create),
                        labelText:
                            'Enter the Text Prompt, eg: emotional piano pop',
                        labelStyle: GoogleFonts.beVietnamPro(
                          fontSize: 16,
                          color: isDarkTheme ? Colors.black : Colors.black,
                        ),
                        filled: true,
                        fillColor: isDarkTheme ? Colors.white : Colors.white,
                        border: OutlineInputBorder(
                          borderSide: BorderSide(
                            color: isDarkTheme ? Colors.grey : Colors.grey,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                            color: highlightColor,
                            width: 1.5,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                            color: Colors.black,
                            width: 2.0,
                          ),
                        ),
                        disabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                            color: Colors.grey,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 15),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(4.0),
              child:
                  _isGenerating
                      ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Color(0xFFFFC0CB),
                            ),
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Nhạc Đang Trong Quá Trình Xử Lý',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      )
                      : ElevatedButton(
                        onPressed: _isGenerating ? null : _generateMusic,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: highlightColor,
                          foregroundColor: cardTextColor,
                          shape: RoundedRectangleBorder(
                            side: BorderSide(color: cardTextColor, width: 1.0),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          disabledBackgroundColor: highlightColor.withOpacity(
                            0.5,
                          ),
                        ),
                        child: Text(
                          'Tạo Nhạc',
                          style: GoogleFonts.beVietnamPro(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: cardTextColor,
                          ),
                        ),
                      ),
            ),
            if (_generatedAudioPath != null)
              buildMusicCard(
                _generatedAudioPath,
                cardColor,
                cardTextColor,
                _textPromptController,
                context,
                _deleteLocalAudio,
              ),
          ],
        ),
      ),
    );
  }
}
