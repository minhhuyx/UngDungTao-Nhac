import 'dart:io';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'home_screen.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'dart:typed_data';

void main() {
  runApp(const MusicPlayerApp());
}

class MusicPlayerApp extends StatelessWidget {
  const MusicPlayerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: HomeScreen(),
    );
  }
}

class MusicPlayScreen extends StatefulWidget {
  final String? generatedAudioPath; // Đường dẫn file cục bộ
  final String? fileUrl; // URL file từ Firebase Storage
  final TextEditingController textPromptController;

  const MusicPlayScreen({
    super.key,
    this.generatedAudioPath,
    this.fileUrl,
    required this.textPromptController,
  });

  @override
  State<MusicPlayScreen> createState() => _MusicPlayScreenState();
}

class _MusicPlayScreenState extends State<MusicPlayScreen> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  double _currentSliderValue = 0;
  Duration _totalDuration = const Duration(seconds: 0);
  bool _isAudioLoaded = false;
  bool _isPlaying = false;
  bool _isSaved = false;

  late BannerAd _bannerAd;
  bool _isBannerAdReady = false;

  @override
  void initState() {
    super.initState();
    _initializeAudio();

    _bannerAd = BannerAd(
      adUnitId: 'ca-app-pub-3940256099942544/6300978111', // banner test
      request: AdRequest(),
      size: AdSize.banner,
      listener: BannerAdListener(
        onAdLoaded: (_) => setState(() => _isBannerAdReady = true),
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
        },
      ),
    )..load();

    _audioPlayer.onPositionChanged.listen((Duration position) {
      if (mounted) {
        setState(() {
          _currentSliderValue = position.inSeconds.toDouble();
        });
      }
    });
    _audioPlayer.onDurationChanged.listen((Duration duration) {
      if (mounted) {
        setState(() {
          _totalDuration = duration;
          _isAudioLoaded = true;
        });
      }
    });
    _audioPlayer.onPlayerStateChanged.listen((PlayerState state) {
      if (mounted) {
        setState(() {
          if (state == PlayerState.playing) {
            _isPlaying = true;
          } else if (state == PlayerState.paused ||
              state == PlayerState.stopped ||
              state == PlayerState.completed) {
            _isPlaying = false;
            if (state == PlayerState.completed ||
                state == PlayerState.stopped) {
              _currentSliderValue = 0;
            }
          }
        });
      }
    });
  }

  Future<void> _initializeAudio() async {
    try {
      if (widget.fileUrl != null) {
        // Phát file từ URL
        await _audioPlayer.setSource(UrlSource(widget.fileUrl!));
        setState(() {
          _isSaved = true; // File từ Firebase đã được lưu
        });
      } else if (widget.generatedAudioPath != null &&
          File(widget.generatedAudioPath!).existsSync()) {
        // Phát file cục bộ
        await _audioPlayer.setSource(
          DeviceFileSource(widget.generatedAudioPath!),
        );
      } else {
        throw Exception('Không có file nhạc để phát');
      }

      final duration = await _audioPlayer.getDuration();
      if (duration != null && mounted) {
        setState(() {
          _totalDuration = duration;
          _isAudioLoaded = true;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi khi tải file âm thanh: $e')),
        );
        setState(() {
          _isAudioLoaded = false;
          _isPlaying = false;
        });
      }
    }
  }

  Future<void> _togglePlayback() async {
    try {
      if (!_isAudioLoaded) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không có file nhạc để phát')),
        );
        return;
      }

      if (_isPlaying) {
        await _audioPlayer.pause();
        setState(() {
          _isPlaying = false;
        });
      } else {
        if (widget.fileUrl != null) {
          await _audioPlayer.play(UrlSource(widget.fileUrl!));
        } else if (widget.generatedAudioPath != null &&
            await File(widget.generatedAudioPath!).exists()) {
          await _audioPlayer.play(DeviceFileSource(widget.generatedAudioPath!));
        }
        setState(() {
          _isPlaying = true;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Lỗi khi phát/tạm dừng: $e')));
      setState(() {
        _isPlaying = false;
      });
    }
  }

  Future<void> _saveSongToFirebase() async {
    try {
      if (widget.generatedAudioPath == null ||
          !await File(widget.generatedAudioPath!).exists()) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không có file nhạc để lưu')),
        );
        return;
      }

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Vui lòng đăng nhập lại')));
        return;
      }

      final userId = user.uid;
      final storageRef = FirebaseStorage.instance.ref('music_history/$userId');
      final fileName = widget.generatedAudioPath!.split('/').last;
      final fileRef = storageRef.child(fileName);
      final file = File(widget.generatedAudioPath!);

      final uploadTask = fileRef.putFile(file);
      await uploadTask.whenComplete(() => null);
      final fileUrl = await fileRef.getDownloadURL();

      setState(() {
        _isSaved = true;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Lưu bài hát thành công!')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Lỗi khi lưu bài hát: $e')));
    }
  }

  @override
  void dispose() {
    _audioPlayer.stop();
    _audioPlayer.dispose();
    _bannerAd.dispose();
    super.dispose();
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;
    final fileName =
        widget.fileUrl != null
            ? widget.fileUrl!.split('%2F').last.split('?').first
            : widget.generatedAudioPath != null
            ? widget.generatedAudioPath!.split('/').last
            : 'No Song Available';

    final highlightColor = isDarkTheme ? Colors.white : Colors.black;
    final textColor = isDarkTheme ? Colors.white : Colors.black;

    return Scaffold(
      backgroundColor: isDarkTheme ? Colors.black : Colors.white,
      appBar: AppBar(
        backgroundColor: isDarkTheme ? Colors.grey[900] : Colors.white,
        automaticallyImplyLeading: false,
        title: Stack(
          alignment: Alignment.center,
          children: [
            Align(
              alignment: Alignment.center,
              child: Text(
                fileName,
                style: TextStyle(color: highlightColor, fontSize: 20),
              ),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                icon: Icon(Icons.arrow_drop_down, color: highlightColor),
                onPressed: () {
                  Navigator.pop(context);
                },
                tooltip: 'Back',
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.save,
                      color: _isSaved ? Colors.grey : highlightColor,
                    ),
                    onPressed:
                        (_isAudioLoaded &&
                                widget.generatedAudioPath != null &&
                                !_isSaved)
                            ? _saveSongToFirebase
                            : null,
                    tooltip: 'Save',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(10.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_isBannerAdReady)
              Container(
                height: _bannerAd.size.height.toDouble(),
                width: _bannerAd.size.width.toDouble(),
                child: AdWidget(ad: _bannerAd),
              ),
            SizedBox(height: 20),
            ClipRRect(
              borderRadius: BorderRadius.circular(16.0),
              child: Container(
                width: MediaQuery.of(context).size.width * 0.8,
                height: MediaQuery.of(context).size.width * 0.8,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  image: const DecorationImage(
                    image: AssetImage('assets/avatar2.png'),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              fileName,
              style: GoogleFonts.poppins(
                color: textColor,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'DIFFRHYTHM AI',
              style: GoogleFonts.poppins(color: textColor, fontSize: 16),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.format_quote, color: textColor),
                SizedBox(width: 16),
                Icon(Icons.favorite_border, color: textColor),
                SizedBox(width: 16),
                Icon(Icons.more_horiz, color: textColor),
              ],
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _formatDuration(
                    Duration(seconds: _currentSliderValue.toInt()),
                  ),
                  style: TextStyle(color: textColor),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Slider(
                    value: _currentSliderValue,
                    min: 0,
                    max:
                        _totalDuration.inSeconds.toDouble() > 0
                            ? _totalDuration.inSeconds.toDouble()
                            : 1.0,
                    onChanged:
                        _isAudioLoaded
                            ? (value) async {
                              setState(() {
                                _currentSliderValue = value;
                              });
                              await _audioPlayer.seek(
                                Duration(seconds: value.toInt()),
                              );
                            }
                            : null,
                    activeColor: highlightColor,
                    inactiveColor:
                        isDarkTheme ? Colors.grey[700] : Colors.black,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _formatDuration(_totalDuration),
                  style: TextStyle(color: textColor),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: Icon(Icons.replay_10, color: highlightColor),
                  onPressed:
                      _isAudioLoaded
                          ? () {
                            setState(() {
                              _currentSliderValue = (_currentSliderValue - 10)
                                  .clamp(
                                    0,
                                    _totalDuration.inSeconds.toDouble(),
                                  );
                              _audioPlayer.seek(
                                Duration(seconds: _currentSliderValue.toInt()),
                              );
                            });
                          }
                          : null,
                  tooltip: 'Rewind 10 seconds',
                ),
                IconButton(
                  icon: Icon(
                    _isPlaying ? Icons.pause : Icons.play_arrow,
                    color: highlightColor,
                    size: 48,
                  ),
                  onPressed: _isAudioLoaded ? _togglePlayback : null,
                  tooltip: 'Play/Pause',
                ),
                IconButton(
                  icon: Icon(Icons.forward_10, color: highlightColor),
                  onPressed:
                      _isAudioLoaded
                          ? () {
                            setState(() {
                              _currentSliderValue = (_currentSliderValue + 10)
                                  .clamp(
                                    0,
                                    _totalDuration.inSeconds.toDouble(),
                                  );
                              _audioPlayer.seek(
                                Duration(seconds: _currentSliderValue.toInt()),
                              );
                            });
                          }
                          : null,
                  tooltip: 'Forward 10 seconds',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
