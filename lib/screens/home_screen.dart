import 'dart:convert';
import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:http/http.dart' as http;
import 'package:collection/collection.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'musicplay_screen.dart';

Widget buildMusicCard(
    String? generatedAudioPath,
    Color cardColor,
    Color cardTextColor,
    TextEditingController textPromptController,
    BuildContext context,
    Function() onDelete,
    ) {
  return Padding(
    padding: const EdgeInsets.only(top: 20.0),
    child: Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.blue, width: 1.5),
      ),
      color: cardColor.withOpacity(0.9),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(5.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(5.0, 0, 5.0, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Generated Music',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: cardTextColor,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.red, size: 20),
                    onPressed: onDelete,
                    tooltip: 'Xóa tệp nhạc',
                  ),
                ],
              ),
            ),
            Divider(
              color: Colors.grey,
              thickness: 0.5,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(5.0, 2.0, 5.0, 2.0),
              child: GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => MusicPlayScreen(
                        generatedAudioPath: generatedAudioPath,
                        textPromptController: textPromptController,
                      ),
                    ),
                  );
                },
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
                      child: Text(
                        generatedAudioPath != null
                            ? " ${generatedAudioPath.split('/').last}"
                            : "No audio available",
                        style: TextStyle(fontSize: 16, color: cardTextColor),
                        overflow: TextOverflow.ellipsis,
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
  );
}

class AppConstants {
  static const int maxSongs = 5;
  static const List<String> supportedFormats = ['mp3', 'wav', 'ogg'];
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue:
    'https://a201-2001-ee0-4f50-20e0-aa8b-4c16-c595-5c5a.ngrok-free.app',
  );
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

      final databaseRef = FirebaseDatabase.instance.ref('lyrics_history/$userId');
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi khi xóa tệp: $e')),
        );
      }
    }
  }

  Future<void> _pickAudioFile() async {
    try {
      const XTypeGroup typeGroup = XTypeGroup(
        label: 'audio',
        extensions: AppConstants.supportedFormats,
      );
      final XFile? file = await openFile(acceptedTypeGroups: [typeGroup]);
      if (file != null) {
        final extension = file.path.split('.').last.toLowerCase();
        if (!AppConstants.supportedFormats.contains(extension)) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Định dạng không được hỗ trợ. Vui lòng chọn ${AppConstants.supportedFormats.join(", ")}',
              ),
            ),
          );
          return;
        }
        if (!await _isValidAudioDuration(file.path)) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Tệp âm thanh phải dài ít nhất 1 giây'),
            ),
          );
          return;
        }
        setState(() {
          _selectedPrompt = PromptType.audio;
          _selectedAudioPath = file.path;
        });
        await _uploadAudioFile(file.path);
      } else {
        setState(() {
          _selectedPrompt = PromptType.none;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi khi chọn file âm thanh: $e')),
      );
    }
  }

  Future<bool> _isValidAudioDuration(String filePath) async {
    final player = AudioPlayer();
    try {
      await player.setSource(DeviceFileSource(filePath));
      final duration = await player.getDuration();
      await player.dispose();
      return duration != null && duration.inSeconds >= 1;
    } catch (e) {
      return false;
    }
  }

  Future<bool> _isConnected() async {
    final connectivity = Connectivity();
    var connectivityResult = await connectivity.checkConnectivity();
    return connectivityResult != ConnectivityResult.none;
  }

  Future<void> _toggleRecording() async {
    try {
      if (_isRecording) {
        final path = await _recorder.stopRecorder();
        if (path != null) {
          if (!await _isValidAudioDuration(path)) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Tệp âm thanh phải dài ít nhất 1 giây'),
              ),
            );
            return;
          }
          setState(() {
            _isRecording = false;
            _selectedPrompt = PromptType.audio;
            _selectedAudioPath = path;
          });
          await _uploadAudioFile(path);
        }
      } else {
        var status = await Permission.microphone.request();
        if (status.isGranted) {
          final directory = await getTemporaryDirectory();
          final filePath = '${directory.path}/recorded_audio.aac';
          await _recorder.startRecorder(toFile: filePath);
          setState(() {
            _isRecording = true;
          });
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Quyền microphone bị từ chối.')),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi khi ghi âm: $e')),
      );
    }
  }

  Future<void> _uploadAudioFile(String filePath) async {
    if (_selectedPrompt != PromptType.audio) return;
    if (!File(filePath).existsSync()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tệp âm thanh không tồn tại')),
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

    final String uploadUrl = '${AppConstants.apiBaseUrl}/generate_music';
    var request = http.MultipartRequest('POST', Uri.parse(uploadUrl));
    request.files.add(await http.MultipartFile.fromPath('file', filePath));

    try {
      var response = await request.send();
      if (response.statusCode == 200) {
        var responseBody = await response.stream.bytesToString();
        var data = jsonDecode(responseBody);
        String newAudioPath = data['audio_link'];
        setState(() {
          _selectedAudioPath = newAudioPath;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload file thất bại: ${response.statusCode}'),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi khi upload file: $e')),
      );
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
      String? audioLink;

      if (_selectedPrompt == PromptType.audio) {
        final request = http.MultipartRequest(
          'POST',
          Uri.parse('$ngrokUrl/upload_audio'),
        );
        request.files.add(
          await http.MultipartFile.fromPath('audio', _selectedAudioPath!),
        );
        final response = await request.send();
        if (response.statusCode != 200) {
          throw Exception('Tải file âm thanh thất bại: ${response.statusCode}');
        }
        final responseData = await response.stream.bytesToString();
        audioLink = jsonDecode(responseData)['filename'];
      }

      Map<String, dynamic> requestData = {
        'lyrics': _lyricsController.text.trim(),
        'prompt_type': _selectedPrompt == PromptType.text ? 'text' : 'audio',
      };

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
        requestData['ref_prompt'] = _textPromptController.text.trim();
      } else {
        requestData['audio_link'] = audioLink;
      }

      final response = await http.post(
        Uri.parse('$ngrokUrl/generate_music'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestData),
      );

      if (response.statusCode == 200) {
        final bytes = response.bodyBytes;
        if (bytes.isEmpty) throw Exception('Dữ liệu MP3 từ server trống');

        final directory = await getTemporaryDirectory();
        final prefs = await SharedPreferences.getInstance();
        int counter = (prefs.getInt('music_counter') ?? 0) + 1;
        final filePath = '${directory.path}/music_${counter.toString().padLeft(2, '0')}.mp3';
        final file = File(filePath);
        await file.writeAsBytes(bytes);
        await prefs.setInt('music_counter', counter);
        await prefs.setString('generated_audio_path', filePath);

        setState(() {
          _generatedAudioPath = filePath;
          _selectedAudioPath = null;
          _lyricsController.clear();
          _textPromptController.text = '';
          _selectedPrompt = PromptType.none;
          _isGenerating = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tạo nhạc thành công! Nhấn vào card để nghe'),
          ),
        );
      } else {
        throw Exception(
          'Lỗi từ server: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi khi tạo nhạc: $e')),
      );
      setState(() {
        _generatedAudioPath = null;
        _isGenerating = false;
      });
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('generated_audio_path');
    }
  }

  bool _isValidLyricsFormat(String lyrics) {
    final lines = lyrics.trim().split('\n');
    final regex = RegExp(r'^\[\d{2}:\d{2}\.\d{2}\].+$');
    return lines.every(
          (line) => line.trim().isEmpty || regex.hasMatch(line.trim()),
    );
  }

  Future<void> _initRecorder() async {
    try {
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi khi khởi tạo recorder: $e')),
      );
    }
  }

  Future<void> _loadGeneratedAudioPath() async {
    final prefs = await SharedPreferences.getInstance();
    final savedPath = prefs.getString('generated_audio_path');
    if (savedPath != null && await File(savedPath).exists()) {
      setState(() {
        _generatedAudioPath = savedPath;
      });
    } else {
      await prefs.remove('generated_audio_path');
    }
  }

  Future<void> _loadHistorySongs() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng đăng nhập để xem lịch sử')),
      );
      return;
    }
    final userId = user.uid;

    try {
      final databaseRef = FirebaseDatabase.instance.ref('lyrics_history/$userId');
      databaseRef.orderByChild('created_at').onValue.listen(
            (event) {
          final data = event.snapshot.value;
          final List<Map<String, dynamic>> loadedSongs = [];
          if (data != null && data is Map) {
            data.forEach((key, value) {
              if (value is Map) {
                loadedSongs.add({
                  'id': key,
                  'title': value['title']?.toString() ?? 'Unknown Title',
                  'theme_name':
                  value['theme_name']?.toString() ?? 'Unknown Style',
                  'file_url': value['file_url']?.toString() ?? '',
                  'created_at':
                  value['created_at'] is int
                      ? value['created_at']
                      : DateTime.now().millisecondsSinceEpoch,
                });
              }
            });
            loadedSongs.sort(
                  (a, b) => (b['created_at'] as int).compareTo(
                a['created_at'] as int,
              ),
            );
          }

          setState(() {
            _historySongs = loadedSongs;
          });
        },
        onError: (error) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Lỗi khi tải lịch sử: $error')),
          );
        },
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi khi truy cập Firebase: $e')),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _initRecorder();
    _loadGeneratedAudioPath();
    _loadHistorySongs();
  }

  @override
  void dispose() {
    _recorder.closeRecorder();
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
        padding: const EdgeInsets.all(16.0),
        controller: _scrollController,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enter Your Lyrics:',
              style: GoogleFonts.poppins(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: _lyricsController,
              maxLines: 5,
              style: GoogleFonts.raleway(fontSize: 18, color: Colors.black),
              decoration: InputDecoration(
                hintText: 'Type your lyrics here...',
                hintStyle: GoogleFonts.raleway(
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
                  'Best Practices Guide',
                  style: GoogleFonts.poppins(
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
                          style: GoogleFonts.raleway(
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
                                  style: GoogleFonts.raleway(
                                    fontSize: 15,
                                    color: cardTextColor,
                                  ),
                                ),
                                Text(
                                  '[00:13.20] Your shadow dances on the dashboard shrine',
                                  style: GoogleFonts.raleway(
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
                          style: GoogleFonts.raleway(
                            fontSize: 15,
                            color: cardTextColor,
                          ),
                        ),
                        Text(
                          '3. Supported Languages\n'
                              'Chinese and English\n'
                              'More languages coming soon',
                          style: GoogleFonts.raleway(
                            fontSize: 15,
                            color: cardTextColor,
                          ),
                        ),
                        Text(
                          '4. Others\n'
                              'If loading audio result is slow, you can select Output Format as mp3 in Advanced Settings.',
                          style: GoogleFonts.raleway(
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
                      'Music Duration',
                      style: GoogleFonts.poppins(
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
                              style: GoogleFonts.raleway(
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
                              style: GoogleFonts.raleway(
                                fontSize: 20,
                                color: cardTextColor,
                              ),
                            ),
                            value: 285,
                            groupValue: _selectedDuration,
                            activeColor: highlightColor,
                            onChanged: (int? value) {
                              setState(() {
                                _selectedDuration = value!;
                              });
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
              color: _selectedPrompt == PromptType.audio ? highlightColor : cardColor,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Audio Prompt',
                      style: GoogleFonts.poppins(
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
                            onPressed: _selectedPrompt == PromptType.text ? null : () {
                              setState(() {
                                _selectedPrompt = PromptType.audio;
                              });
                              _pickAudioFile();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: highlightColor,
                              foregroundColor: cardTextColor,
                              side: BorderSide(color: cardTextColor, width: 1.0),
                            ),
                            child: Text(
                              'Upload Audio',
                              style: GoogleFonts.raleway(
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
                            onPressed: _selectedPrompt == PromptType.text ? null : _toggleRecording,
                            style: ElevatedButton.styleFrom(
                              side: BorderSide(color: cardTextColor, width: 1.0),
                              backgroundColor: _isRecording ? Colors.red : highlightColor,
                              foregroundColor: cardTextColor,
                            ),
                            child: Text(
                              _isRecording ? 'Stop Recording' : 'Record',
                              style: GoogleFonts.raleway(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: cardTextColor,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
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
                        const SizedBox(width: 15),
                        Expanded(
                          child: Text(
                            "File: ${_selectedAudioPath!.split('/').last}",
                            style: TextStyle(fontSize: 16, color: cardTextColor),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 15),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () {
                            setState(() {
                              _selectedAudioPath = null;
                            });
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
                side: BorderSide(color: highlightColor, width: 1.5),
              ),
              color: _selectedPrompt == PromptType.text ? highlightColor : cardColor,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Text Prompt',
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: cardTextColor,
                      ),
                    ),
                    const SizedBox(height: 15),
                    TextField(
                      controller: _textPromptController,
                      enabled: _selectedPrompt != PromptType.audio,
                      onTap: () {
                        if (_selectedPrompt != PromptType.audio) {
                          setState(() {
                            _selectedPrompt = PromptType.text;
                            _selectedAudioPath = null;
                          });
                        }
                      },
                      style: GoogleFonts.raleway(fontSize: 16, color: Colors.black),
                      decoration: InputDecoration(
                        labelText: 'Enter the Text Prompt, eg: emotional piano pop',
                        labelStyle: GoogleFonts.raleway(
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
                          borderSide: BorderSide(color: highlightColor, width: 1.5),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.black, width: 2.0),
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
              child: _isGenerating
                  ? const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFFC0CB)),
                  ),
                  SizedBox(width: 10),
                  Text(
                    'Đang tạo nhạc...',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
                  disabledBackgroundColor: highlightColor.withOpacity(0.5),
                ),
                child: Text(
                  'Generate Music',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: cardTextColor,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 15),
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