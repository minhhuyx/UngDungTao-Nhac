import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:rxdart/rxdart.dart';
import 'package:provider/provider.dart';
import '../main.dart'; // Import để sử dụng MyAppState
import 'home_screen.dart';
import 'lyrics_screen.dart';
import 'musicplay_screen.dart'; // Import MusicPlayScreen

class LyricsEntry {
  final String key;
  final String generatedLyrics;
  final String language;
  final String theme;
  final String tags;
  final String category;
  final DateTime date;
  final String? fileUrl; // Trường lưu đường dẫn file nhạc

  LyricsEntry(
      this.key,
      this.generatedLyrics,
      this.language,
      this.theme,
      this.tags,
      this.category,
      this.date, {
        this.fileUrl,
      });
}

// Custom AppBar Widget
class CustomHistoryAppBar extends StatelessWidget implements PreferredSizeWidget {
  final Color highlightColor;

  const CustomHistoryAppBar({Key? key, required this.highlightColor}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final double appBarHeight = AppBar().preferredSize.height;
    final double imageHeight = appBarHeight * 10.0; // điều chỉnh phù hợp

    return AppBar(
      title: const Text('Lịch Sử'),
      backgroundColor: highlightColor,
      actions: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Image.asset(
            'assets/logo.png',
            height: imageHeight,
            fit: BoxFit.contain,
          ),
        ),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

// Custom TabBar Widget
class CustomHistoryTabBar extends StatelessWidget implements PreferredSizeWidget {
  final TabController tabController;
  final int currentTabIndex;
  final Color highlightColor = const Color(0xFFADD8E6);

  const CustomHistoryTabBar({
    Key? key,
    required this.tabController,
    required this.currentTabIndex,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 45,
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(20.0),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          splashFactory: NoSplash.splashFactory, // Disable ripple effect
        ),
        child: TabBar(
          controller: tabController,
          isScrollable: false,
          indicatorSize: TabBarIndicatorSize.tab,
          indicator: BoxDecoration(
            borderRadius: BorderRadius.circular(20.0),
            color: highlightColor,
          ),
          dividerColor: Colors.transparent,
          labelColor: Colors.black,
          unselectedLabelColor: Colors.black54,
          labelPadding: EdgeInsets.zero,
          splashFactory: NoSplash.splashFactory, // Additional safeguard
          overlayColor: MaterialStateProperty.all(Colors.transparent), // Disable overlay
          tabs: [
            Tab(
              child: Container(
                alignment: Alignment.center,
                child: Text(
                  'Bài hát',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: currentTabIndex == 0 ? Colors.black : Colors.black54,
                  ),
                ),
              ),
            ),
            Tab(
              child: Container(
                alignment: Alignment.center,
                child: Text(
                  'Lời nhạc',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: currentTabIndex == 1 ? Colors.black : Colors.black54,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(60.0);
}

class HistoryScreen extends StatefulWidget {
  final Function(int) onNavigate; // Callback để điều hướng

  const HistoryScreen({Key? key, required this.onNavigate}) : super(key: key);

  @override
  _HistoryScreenState createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> with SingleTickerProviderStateMixin {
  final DatabaseReference _databaseRef = FirebaseDatabase.instance.ref();
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final BehaviorSubject<List<LyricsEntry>> _mySongsSubject =
  BehaviorSubject<List<LyricsEntry>>();
  final BehaviorSubject<List<LyricsEntry>> _favoritesSubject =
  BehaviorSubject<List<LyricsEntry>>();
  late TabController _tabController;
  int _currentTabIndex = 0;

  final highlightColor = const Color(0xFFADD8E6);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_handleTabSelection);
    _setupStreams();
  }

  void _handleTabSelection() {
    setState(() {
      _currentTabIndex = _tabController.index;
    });
    print('Selected tab index: $_currentTabIndex');
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabSelection);
    _tabController.dispose();
    _mySongsSubject.close();
    _favoritesSubject.close();
    super.dispose();
  }

  void _setupStreams() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print('No user logged in');
      return;
    }

    final userId = user.uid;

    _databaseRef
        .child('lyrics_history/$userId')
        .orderByChild('created_at')
        .onValue
        .listen((event) async {
      print('onValue triggered with snapshot: ${event.snapshot.exists}');
      final List<LyricsEntry> mySongsHistory = [];
      final List<LyricsEntry> favoritesHistory = [];

      if (event.snapshot.exists) {
        final data = Map<String, dynamic>.from(event.snapshot.value as Map);
        data.forEach((key, value) {
          final entry = Map<String, dynamic>.from(value);
          final timestamp = entry['created_at'] ?? 0;
          final category = entry['category'] ?? 'favorites';

          print('Entry: $key, Category: $category, Timestamp: $timestamp');

          final date = timestamp != 0
              ? DateTime.fromMillisecondsSinceEpoch(timestamp)
              : DateTime.now();

          final lyricsEntry = LyricsEntry(
            key,
            entry['generated_lyrics'] ?? '',
            entry['language'] ?? '',
            entry['theme'] ?? '',
            entry['tags'] ?? '',
            category,
            date,
            fileUrl: entry['file_url'] ?? null,
          );

          if (category == 'my_songs') {
            mySongsHistory.add(lyricsEntry);
          } else {
            favoritesHistory.add(lyricsEntry);
          }
        });
      } else {
        print('No data available in lyrics_history/$userId');
      }

      try {
        final storageRef = _storage.ref().child('music_history/$userId');
        final listResult = await storageRef.listAll();
        for (var item in listResult.items) {
          final url = await item.getDownloadURL();
          final metadata = await item.getMetadata();
          final timestamp = metadata.timeCreated?.millisecondsSinceEpoch ?? 0;
          final date = timestamp != 0
              ? DateTime.fromMillisecondsSinceEpoch(timestamp)
              : DateTime.now();

          mySongsHistory.add(
            LyricsEntry(
              item.name,
              '',
              '',
              '',
              '',
              'my_songs',
              date,
              fileUrl: url,
            ),
          );
        }
      } catch (e) {
        print('Error fetching music files: $e');
      }

      mySongsHistory.sort((a, b) => b.date.compareTo(a.date));
      favoritesHistory.sort((a, b) => b.date.compareTo(a.date));

      print('My Songs: ${mySongsHistory.length}, Favorites: ${favoritesHistory.length}');
      _mySongsSubject.add(mySongsHistory);
      _favoritesSubject.add(favoritesHistory);
    });
  }

  Future<void> _deleteEntry(String category, String key, {String? fileUrl}) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vui lòng đăng nhập lại')),
        );
        return;
      }

      final userId = user.uid;
      String? fileName;
      if (fileUrl != null) {
        fileName = fileUrl.split('%2F').last.split('?').first;
      }

      // Xóa dữ liệu từ Firebase Database nếu category không phải là file nhạc từ storage
      if (category != 'my_songs' || fileUrl == null) {
        await _databaseRef.child('lyrics_history/$userId/$key').remove();
      }

      // Xóa file từ Firebase Storage nếu có
      if (fileName != null) {
        final storageRef = _storage.ref('music_history/$userId/$fileName');
        await storageRef.delete();
      }

      // Hiển thị thông báo xóa thành công
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã xóa mục')),
      );

      // Tải lại dữ liệu để cập nhật danh sách
      if (mounted) {
        _setupStreams();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi khi xóa mục: $e')),
      );
    }
  }

  void _showLyricsDialog(LyricsEntry entry) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
          side: BorderSide(color: Colors.transparent, width: 0),
        ),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Song Lyrics'),
            IconButton(
              icon: const Icon(Icons.copy),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: entry.generatedLyrics));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Lyrics copied to clipboard!')),
                );
              },
              tooltip: 'Copy lyrics',
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Text(
            entry.generatedLyrics,
            style: const TextStyle(fontSize: 16),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return DateFormat('yyyy-MM-dd – kk:mm').format(date);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomHistoryAppBar(highlightColor: highlightColor),
      body: Stack(
        children: [
          Column(
            children: [
              const SizedBox(height: 10),
              CustomHistoryTabBar(
                tabController: _tabController,
                currentTabIndex: _currentTabIndex,
              ),
              const SizedBox(height: 5),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    StreamBuilder<List<LyricsEntry>>(
                      stream: _mySongsSubject.stream,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        if (snapshot.hasError) {
                          return Center(child: Text('Error: ${snapshot.error}'));
                        }
                        final history = snapshot.data ?? [];
                        return ListView.builder(
                          itemCount: history.length,
                          itemBuilder: (context, index) {
                            final entry = history[index];
                            return Card(
                              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10.0),
                                side: const BorderSide(color: Colors.transparent, width: 0),
                              ),
                              child: Theme(
                                data: Theme.of(context).copyWith(
                                  splashFactory: NoSplash.splashFactory, // Disable ripple effect
                                ),
                                child: ListTile(
                                  onTap: () {
                                    if (entry.fileUrl != null) {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => MusicPlayScreen(
                                            fileUrl: entry.fileUrl,
                                            textPromptController: TextEditingController(text: ''),
                                          ),
                                        ),
                                      );
                                    } else {
                                      _showLyricsDialog(entry);
                                    }
                                  },
                                  title: Text(
                                    entry.fileUrl != null ? ' ${entry.key}' : 'Song Lyrics',
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      if (entry.language.isNotEmpty)
                                        Text('Ngôn ngữ: ${entry.language}'),
                                      if (entry.theme.isNotEmpty) Text('Chủ đề: ${entry.theme}'),
                                      if (entry.tags.isNotEmpty) Text('Thể loại: ${entry.tags}'),
                                      Text('Thời gian tạo: ${_formatDate(entry.date)}'),
                                    ],
                                  ),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.red),
                                    onPressed: () => _deleteEntry(
                                      'my_songs',
                                      entry.key,
                                      fileUrl: entry.fileUrl,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                    StreamBuilder<List<LyricsEntry>>(
                      stream: _favoritesSubject.stream,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        if (snapshot.hasError) {
                          return Center(child: Text('Error: ${snapshot.error}'));
                        }
                        final history = snapshot.data ?? [];
                        return ListView.builder(
                          itemCount: history.length,
                          itemBuilder: (context, index) {
                            final entry = history[index];
                            return Card(
                              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10.0),
                                side: const BorderSide(color: Colors.transparent, width: 0),
                              ),
                              child: Theme(
                                data: Theme.of(context).copyWith(
                                  splashFactory: NoSplash.splashFactory, // Disable ripple effect
                                ),
                                child: ListTile(
                                  onTap: () => _showLyricsDialog(entry),
                                  title: const Text(
                                    'Song Lyrics',
                                    style: TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      if (entry.language.isNotEmpty)
                                        Text('Ngôn ngữ: ${entry.language}'),
                                      if (entry.theme.isNotEmpty) Text('Chủ đề: ${entry.theme}'),
                                      if (entry.tags.isNotEmpty) Text('Thể loại: ${entry.tags}'),
                                      Text('Thời gian tạo: ${_formatDate(entry.date)}'),
                                    ],
                                  ),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.red),
                                    onPressed: () => _deleteEntry('favorites', entry.key),
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          StreamBuilder<List<LyricsEntry>>(
            stream: _mySongsSubject.stream,
            builder: (context, mySongsSnapshot) {
              return StreamBuilder<List<LyricsEntry>>(
                stream: _favoritesSubject.stream,
                builder: (context, favoritesSnapshot) {
                  bool isMySongsEmpty = mySongsSnapshot.data?.isEmpty ?? true;
                  bool isFavoritesEmpty = favoritesSnapshot.data?.isEmpty ?? true;

                  print('Current Tab Index: $_currentTabIndex');
                  print('isMySongsEmpty: $isMySongsEmpty, isFavoritesEmpty: $isFavoritesEmpty');

                  if ((_currentTabIndex == 0 && isMySongsEmpty) ||
                      (_currentTabIndex == 1 && isFavoritesEmpty)) {
                    return Align(
                      alignment: Alignment.bottomRight,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Container(
                          width: 56,
                          height: 56,
                          child: FloatingActionButton(
                            onPressed: () {
                              final appState = Provider.of<MyAppState>(context, listen: false);
                              if (_currentTabIndex == 0) {
                                print('Navigating to HomeScreen (index 0)');
                                appState.setSelectedIndex(0);
                              } else {
                                print('Navigating to LyricsScreen (index 1) from HistoryScreen');
                                appState.setSelectedIndex(1);
                              }
                            },
                            backgroundColor: Colors.transparent,
                            elevation: 0,
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF40C4FF),
                                    Color(0xFF00B7A8),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                              ),
                              child: const Icon(
                                Icons.add,
                                color: Colors.white,
                                size: 28,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              );
            },
          ),
        ],
      ),
      backgroundColor: Colors.white,
    );
  }
}