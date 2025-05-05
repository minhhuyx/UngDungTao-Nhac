import 'dart:io';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';

// Class HistoryManager để quản lý lịch sử
class HistoryManager {
  static const int maxSongs = 5; // Giới hạn 5 bài hát

  Future<void> addSongToHistory({
    required String themeName,
    required String title,
    required String lyrics,
    required File songFile,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('Người dùng chưa đăng nhập.');
    }

    final userId = user.uid;
    final databaseRef = FirebaseDatabase.instance.ref('history/$userId');
    final storageRef = FirebaseStorage.instance.ref('history/$userId');

    try {
      // 1. Tải file MP3 lên Firebase Storage
      final fileName = songFile.path.split('/').last;
      final fileRef = storageRef.child(fileName);
      await fileRef.putFile(songFile);
      final fileUrl = await fileRef.getDownloadURL();

      // 2. Kiểm tra số lượng bài hát trong lịch sử
      final snapshot = await databaseRef.orderByChild('created_at').get();
      final songs = <String, dynamic>{};
      if (snapshot.exists) {
        songs.addAll(Map<String, dynamic>.from(snapshot.value as Map));
      }

      if (songs.length >= maxSongs) {
        // Xóa bài hát cũ nhất
        final oldestSongKey = songs.keys.first;
        final oldestSong = Map<String, dynamic>.from(songs[oldestSongKey]);
        final oldestFileUrl = oldestSong['file_url'] as String;
        final oldestFileName = oldestFileUrl.split('/').last.split('?').first;
        await storageRef.child(oldestFileName).delete();
        await databaseRef.child(oldestSongKey).remove();
      }

      // 3. Thêm bài hát mới
      final newSongRef = databaseRef.push();
      await newSongRef.set({
        'theme_name': themeName,
        'title': title,
        'lyrics': lyrics,
        'file_url': fileUrl,
        'created_at': ServerValue.timestamp,
      });
    } catch (e) {
      print('Lỗi khi thêm bài hát vào lịch sử: $e');
      rethrow;
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
  String _selectedAlgorithm = 'euler';
  String _selectedFormat = 'mp3';
  double _sliderValueSeed = 0.0;
  double _sliderValueSteps = 10.0;
  double _sliderValueCfg = 1.0;

  final AudioPlayer _audioPlayer = AudioPlayer();
  String? _selectedAudioPath;
  bool _isPlaying = false;

  PromptType _selectedPrompt = PromptType.none;
  final ScrollController _scrollController = ScrollController();

  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  bool _isRecording = false;

  final HistoryManager _historyManager = HistoryManager();

  Future<void> _toggleAudioPlayback() async {
    if (_selectedAudioPath == null) return;

    try {
      if (_isPlaying) {
        await _audioPlayer.pause();
        setState(() {
          _isPlaying = false;
        });
      } else {
        await _audioPlayer.play(DeviceFileSource(_selectedAudioPath!));
        setState(() {
          _isPlaying = true;
        });
      }
    } catch (e) {
      print('Lỗi khi phát audio: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Lỗi khi phát audio: $e')));
    }
  }

  Future<void> _toggleRecording() async {
    try {
      if (_isRecording) {
        final path = await _recorder.stopRecorder();
        if (path != null) {
          setState(() {
            _isRecording = false;
            _selectedPrompt = PromptType.audio;
            _selectedAudioPath = path;
            _isPlaying = false;
          });
          print("Đã ghi âm xong: $_selectedAudioPath");
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
          print("Đang ghi âm...");
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Quyền microphone bị từ chối.')),
          );
        }
      }
    } catch (e) {
      print('Lỗi khi ghi âm: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Lỗi khi ghi âm: $e')));
    }
  }

  Future<void> _pickAudioFile() async {
    try {
      const XTypeGroup typeGroup = XTypeGroup(
        label: 'audio',
        extensions: ['mp3', 'wav', 'm4a'],
      );
      final XFile? file = await openFile(acceptedTypeGroups: [typeGroup]);
      if (file != null) {
        setState(() {
          _selectedPrompt = PromptType.audio;
          _selectedAudioPath = file.path;
          _isPlaying = false;
        });
        print("Đã chọn file âm thanh: $_selectedAudioPath");
      } else {
        setState(() {
          _selectedPrompt = PromptType.none;
        });
        print("Không có file nào được chọn.");
      }
    } catch (e) {
      print('Lỗi khi chọn file âm thanh: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Lỗi khi chọn file âm thanh: $e')));
    }
  }

  Future<void> _generateMusic() async {
    if (_lyricsController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập lời bài hát!')),
      );
      return;
    }

    if (_selectedPrompt == PromptType.audio && _selectedAudioPath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng chọn hoặc ghi âm một file âm thanh!'),
        ),
      );
      return;
    }

    try {
      // Giả lập việc tạo file âm thanh (dùng file đã chọn hoặc ghi âm)
      if (_selectedAudioPath == null) {
        throw Exception('Không có file âm thanh để tạo nhạc.');
      }

      final songFile = File(_selectedAudioPath!);
      if (!await songFile.exists()) {
        throw Exception('File âm thanh không tồn tại.');
      }

      final title = 'Bài Hát ${DateTime.now().toString().substring(0, 19)}';
      final themeName =
          _textPromptController.text.isNotEmpty
              ? _textPromptController.text
              : 'Unknown Style';

      // Lưu bài hát vào lịch sử trên Firebase
      await _historyManager.addSongToHistory(
        themeName: themeName,
        title: title,
        lyrics: _lyricsController.text,
        songFile: songFile,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã tạo và lưu bài hát vào lịch sử!')),
      );

      // Reset các trường sau khi tạo
      setState(() {
        _lyricsController.clear();
        _textPromptController.clear();
        _selectedAudioPath = null;
        _selectedPrompt = PromptType.none;
        _isPlaying = false;
      });
    } catch (e) {
      print('Lỗi khi tạo nhạc: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Lỗi khi tạo nhạc: $e')));
    }
  }

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      if (_scrollController.position.userScrollDirection !=
              ScrollDirection.idle &&
          _selectedPrompt != PromptType.none) {
        setState(() {
          _selectedPrompt = PromptType.none;
        });
      }
    });

    _recorder.openRecorder();
  }

  @override
  void dispose() {
    if (_selectedAudioPath != null &&
        _selectedAudioPath!.contains('recorded_audio')) {
      try {
        File(_selectedAudioPath!).deleteSync();
      } catch (e) {
        print('Lỗi khi xóa file ghi âm: $e');
      }
    }
    _recorder.closeRecorder();
    _audioPlayer.dispose();
    _scrollController.dispose();
    _lyricsController.dispose();
    _textPromptController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDarkTheme ? Colors.white : Colors.black87;
    final cardColor = Colors.white; // Giữ nguyên màu trắng
    final highlightColor = const Color(0xFFFFC0CB); // Giữ nguyên màu hồng
    final cardTextColor = Colors.black87; // Giữ nguyên màu đen

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'DiffRhythm Music Generator',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
        backgroundColor: isDarkTheme ? null : highlightColor,
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
              color: highlightColor, // Giữ nguyên màu hồng
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
                          color: cardColor, // Giữ nguyên màu trắng
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
                side: isDarkTheme
                    ? BorderSide(color: highlightColor, width: 1.5)
                    : BorderSide(color: highlightColor, width: 1.5),
              ),
              color: cardColor, // Giữ nguyên màu trắng
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
                side: isDarkTheme
                    ? BorderSide(color: highlightColor, width: 1.5)
                    : BorderSide(color: highlightColor, width: 1.5),
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
                            onPressed: _selectedPrompt == PromptType.text
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
                            onPressed: _selectedPrompt == PromptType.text
                                ? null
                                : _toggleRecording,
                            style: ElevatedButton.styleFrom(
                              side: BorderSide(
                                color: cardTextColor,
                                width: 1.0,
                              ),
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
                        IconButton(
                          icon: Icon(
                            _isPlaying ? Icons.pause : Icons.play_arrow,
                            color: highlightColor,
                          ),
                          onPressed: _toggleAudioPlayback,
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
                              if (_isPlaying) {
                                _audioPlayer.stop();
                                _isPlaying = false;
                              }
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
                side: isDarkTheme
                    ? BorderSide(color: highlightColor, width: 1.5)
                    : BorderSide(color: highlightColor, width: 1.5),
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
                          });
                        }
                      },
                      style: GoogleFonts.raleway(
                        fontSize: 16,
                        color: Colors.black,
                      ),
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
                      ),
                    ),
                  ],
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
                  'Advanced Settings',
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
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Card(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          color: cardColor,
                          child: Padding(
                            padding: const EdgeInsets.all(10.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          'Seed',
                                          style: GoogleFonts.raleway(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: cardTextColor,
                                          ),
                                        ),
                                        const Spacer(),
                                        Text(
                                          _sliderValueSeed.toInt().toString(),
                                          style: TextStyle(
                                            color: cardTextColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Slider(
                                      value: _sliderValueSeed,
                                      min: 0.0,
                                      max: 2147483647,
                                      activeColor: highlightColor,
                                      inactiveColor: Colors.grey[300],
                                      onChanged: (double newValue) {
                                        setState(() {
                                          _sliderValueSeed = newValue;
                                        });
                                      },
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 15),
                                Text(
                                  'Diffusion Steps',
                                  style: GoogleFonts.raleway(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: cardTextColor,
                                  ),
                                ),
                                Slider(
                                  value: _sliderValueSteps,
                                  min: 10.0,
                                  max: 100.0,
                                  activeColor: highlightColor,
                                  inactiveColor: Colors.grey[300],
                                  divisions: 90,
                                  label: _sliderValueSteps.round().toString(),
                                  onChanged: (double newValue) {
                                    setState(() {
                                      _sliderValueSteps = newValue;
                                    });
                                  },
                                ),
                                Text(
                                  'CFG Strength',
                                  style: GoogleFonts.raleway(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: cardTextColor,
                                  ),
                                ),
                                Slider(
                                  value: _sliderValueCfg,
                                  min: 1.0,
                                  max: 10.0,
                                  activeColor: highlightColor,
                                  inactiveColor: Colors.grey[300],
                                  divisions: 18,
                                  label: _sliderValueCfg.toStringAsFixed(1),
                                  onChanged: (double newValue) {
                                    setState(() {
                                      _sliderValueCfg = newValue;
                                    });
                                  },
                                ),
                                Text(
                                  'ODE Solver',
                                  style: GoogleFonts.raleway(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: cardTextColor,
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    RadioListTile<String>(
                                      title: Text(
                                        'Euler',
                                        style: TextStyle(color: cardTextColor),
                                      ),
                                      value: 'euler',
                                      groupValue: _selectedAlgorithm,
                                      activeColor: highlightColor,
                                      onChanged: (String? value) {
                                        setState(() {
                                          _selectedAlgorithm = value!;
                                        });
                                      },
                                    ),
                                    RadioListTile<String>(
                                      title: Text(
                                        'Midpoint',
                                        style: TextStyle(color: cardTextColor),
                                      ),
                                      value: 'midpoint',
                                      groupValue: _selectedAlgorithm,
                                      activeColor: highlightColor,
                                      onChanged: (String? value) {
                                        setState(() {
                                          _selectedAlgorithm = value!;
                                        });
                                      },
                                    ),
                                    RadioListTile<String>(
                                      title: Text(
                                        'RK4',
                                        style: TextStyle(color: cardTextColor),
                                      ),
                                      value: 'rk4',
                                      groupValue: _selectedAlgorithm,
                                      activeColor: highlightColor,
                                      onChanged: (String? value) {
                                        setState(() {
                                          _selectedAlgorithm = value!;
                                        });
                                      },
                                    ),
                                    RadioListTile<String>(
                                      title: Text(
                                        'Implicit Adams',
                                        style: TextStyle(color: cardTextColor),
                                      ),
                                      value: 'implicit_adams',
                                      groupValue: _selectedAlgorithm,
                                      activeColor: highlightColor,
                                      onChanged: (String? value) {
                                        setState(() {
                                          _selectedAlgorithm = value!;
                                        });
                                      },
                                    ),
                                  ],
                                ),
                                Text(
                                  'Output Format',
                                  style: GoogleFonts.raleway(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: cardTextColor,
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    RadioListTile<String>(
                                      title: Text(
                                        'MP3',
                                        style: TextStyle(color: cardTextColor),
                                      ),
                                      value: 'mp3',
                                      groupValue: _selectedFormat,
                                      activeColor: highlightColor,
                                      onChanged: (String? value) {
                                        setState(() {
                                          _selectedFormat = value!;
                                        });
                                      },
                                    ),
                                    RadioListTile<String>(
                                      title: Text(
                                        'WAV',
                                        style: TextStyle(color: cardTextColor),
                                      ),
                                      value: 'wav',
                                      groupValue: _selectedFormat,
                                      activeColor: highlightColor,
                                      onChanged: (String? value) {
                                        setState(() {
                                          _selectedFormat = value!;
                                        });
                                      },
                                    ),
                                    RadioListTile<String>(
                                      title: Text(
                                        'OGG',
                                        style: TextStyle(color: cardTextColor),
                                      ),
                                      value: 'ogg',
                                      groupValue: _selectedFormat,
                                      activeColor: highlightColor,
                                      onChanged: (String? value) {
                                        setState(() {
                                          _selectedFormat = value!;
                                        });
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 15),
            Container(
              width: double.infinity,
              child: Padding(
                padding: const EdgeInsets.all(4.0),
                child: ElevatedButton(
                  onPressed: _generateMusic,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: highlightColor,
                    foregroundColor: cardTextColor,
                    shape: RoundedRectangleBorder(
                      side: BorderSide(color: cardTextColor, width: 1.0),
                      borderRadius: BorderRadius.circular(8),
                    ),
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
            ),
            const SizedBox(height: 15),
          ],
        ),
      ),
    );
  }
}
