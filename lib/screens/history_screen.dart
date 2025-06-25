import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:rxdart/rxdart.dart';
import 'package:provider/provider.dart';
import '../main.dart'; // Import để sử dụng MyAppState
import 'musicplay_screen.dart'; // Import MusicPlayScreen
import 'package:file_picker/file_picker.dart';
import 'dart:typed_data';


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
class CustomHistoryAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  const CustomHistoryAppBar({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;
    final double appBarHeight = AppBar().preferredSize.height;
    final double imageHeight = appBarHeight * 10.0; // Điều chỉnh phù hợp

    return AppBar(
      title: Text('LỊCH SỬ', style: GoogleFonts.beVietnamPro()),
      backgroundColor: const Color(0xFFADD8E6),
      foregroundColor: isDarkTheme ? Colors.white : Colors.black,
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
class CustomHistoryTabBar extends StatelessWidget
    implements PreferredSizeWidget {
  final TabController tabController;
  final int currentTabIndex;

  const CustomHistoryTabBar({
    Key? key,
    required this.tabController,
    required this.currentTabIndex,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;
    final highlightColor =
        isDarkTheme ? Colors.blueGrey[700]! : const Color(0xFFADD8E6);

    return Container(
      height: 45,
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: isDarkTheme ? Colors.grey[800] : Colors.grey[200],
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
          labelColor: isDarkTheme ? Colors.white : Colors.black,
          unselectedLabelColor: isDarkTheme ? Colors.grey[400] : Colors.black54,
          labelPadding: EdgeInsets.zero,
          splashFactory: NoSplash.splashFactory, // Additional safeguard
          overlayColor: MaterialStateProperty.all(
            Colors.transparent,
          ), // Disable overlay
          tabs: [
            Tab(
              child: Container(
                alignment: Alignment.center,
                child: Text(
                  'Bài hát',
                  style: GoogleFonts.beVietnamPro(
                    fontWeight: FontWeight.bold,
                    color:
                        currentTabIndex == 0
                            ? (isDarkTheme ? Colors.white : Colors.black)
                            : (isDarkTheme ? Colors.grey[400] : Colors.black54),
                  ),
                ),
              ),
            ),
            Tab(
              child: Container(
                alignment: Alignment.center,
                child: Text(
                  'Lời nhạc',
                  style: GoogleFonts.beVietnamPro(
                    fontWeight: FontWeight.bold,
                    color:
                        currentTabIndex == 1
                            ? (isDarkTheme ? Colors.white : Colors.black)
                            : (isDarkTheme ? Colors.grey[400] : Colors.black54),
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

class _HistoryScreenState extends State<HistoryScreen>
    with SingleTickerProviderStateMixin {
  final DatabaseReference _databaseRef = FirebaseDatabase.instance.ref();
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final BehaviorSubject<List<LyricsEntry>> _mySongsSubject =
      BehaviorSubject<List<LyricsEntry>>();
  final BehaviorSubject<List<LyricsEntry>> _favoritesSubject =
      BehaviorSubject<List<LyricsEntry>>();
  late TabController _tabController;
  int _currentTabIndex = 0;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';


  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_handleTabSelection);
    _setupStreams();
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.toLowerCase();
    });
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
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  // Hàm lọc danh sách dựa trên từ khóa tìm kiếm
  List<LyricsEntry> _filterEntries(
    List<LyricsEntry> entries,
    String query,
    String tab,
  ) {
    if (query.isEmpty) return entries;
    return entries.where((entry) {
      if (tab == 'my_songs') {
        return entry.key.toLowerCase().contains(query);
      } else {
        return entry.theme.toLowerCase().contains(
          query,
        ); // Tìm kiếm theo chủ đề
      }
    }).toList();
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

              final date =
                  timestamp != 0
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
              final timestamp =
                  metadata.timeCreated?.millisecondsSinceEpoch ?? 0;
              final date =
                  timestamp != 0
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

          print(
            'My Songs: ${mySongsHistory.length}, Favorites: ${favoritesHistory.length}',
          );
          _mySongsSubject.add(mySongsHistory);
          _favoritesSubject.add(favoritesHistory);
        });
  }

  Future<void> _downloadFile(String url, String fileName) async {
    try {
      if (url.isEmpty) { // Kiểm tra url thay vì entry.fileUrl
        _showSnackBar('Không có file để tải xuống');
        return;
      }

      final sanitizedFileName = fileName.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
      Uint8List? fileBytes;

      // Tải dữ liệu byte từ URL
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        fileBytes = response.bodyBytes;
      } else {
        throw Exception('Không thể tải file từ URL: ${response.statusCode}');
      }

      if (fileBytes == null) {
        _showSnackBar('Không thể đọc dữ liệu file');
        return;
      }

      // Sử dụng file_picker để chọn vị trí lưu và ghi file
      String? savePath = await FilePicker.platform.saveFile(
        fileName: sanitizedFileName,
        type: FileType.custom,
        allowedExtensions: ['mp3', 'wav'],
        bytes: fileBytes, // Truyền dữ liệu byte
      );

      if (savePath != null) {
        _showSnackBar('Tải xuống thành công!');
      } else {
        return; // Người dùng hủy chọn
      }
    } catch (e) {
      _showSnackBar('Lỗi khi tải xuống: $e');
    }
  }


  void _showSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _deleteEntry(
    String category,
    String key, {
    String? fileUrl,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Vui lòng đăng nhập lại')));
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Đã xóa mục')));

      // Tải lại dữ liệu để cập nhật danh sách
      if (mounted) {
        _setupStreams();
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Lỗi khi xóa mục: $e')));
    }
  }

  void _showLyricsDialog(LyricsEntry entry) {
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.zero,
              side: BorderSide(color: Colors.transparent, width: 0),
            ),
            backgroundColor: isDarkTheme ? Colors.grey[900] : Colors.white,
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Song Lyrics',
                  style: TextStyle(
                    color: isDarkTheme ? Colors.white : Colors.black,
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.copy,
                    color: isDarkTheme ? Colors.white70 : Colors.black54,
                  ),
                  onPressed: () {
                    Clipboard.setData(
                      ClipboardData(text: entry.generatedLyrics),
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Lyrics copied to clipboard!'),
                      ),
                    );
                  },
                  tooltip: 'Copy lyrics',
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Text(
                entry.generatedLyrics,
                style: TextStyle(
                  fontSize: 16,
                  color: isDarkTheme ? Colors.white : Colors.black,
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Close',
                  style: TextStyle(
                    color: isDarkTheme ? Colors.white70 : Colors.black54,
                  ),
                ),
              ),
            ],
          ),
    );
  }

  String _formatDate(DateTime date) {
    return DateFormat('yyyy-MM-dd – kk:mm').format(date);
  }

  Future<void> downloadFile(
    String url,
    String fileName,
    BuildContext context,
  ) async {
    try {
      // Vệ sinh tên file để loại bỏ ký tự không hợp lệ
      final sanitizedFileName = fileName.replaceAll(
        RegExp(r'[<>:"/\\|?*]'),
        '_',
      );

      // Lấy thư mục Tải xuống (không cần quyền trên Android 13)
      Directory? directory;
      try {
        directory = await getDownloadsDirectory();
        if (directory == null) {
          directory = await getApplicationDocumentsDirectory();
        }
      } catch (e) {
        directory = await getApplicationDocumentsDirectory();
        debugPrint('Lỗi khi lấy thư mục Tải xuống: $e');
      }

      // Tạo đường dẫn file và đảm bảo không ghi đè
      String filePath = '${directory.path}/$sanitizedFileName';
      File file = File(filePath);
      int counter = 1;
      while (await file.exists()) {
        final extension =
            sanitizedFileName.contains('.')
                ? '.${sanitizedFileName.split('.').last}'
                : '';
        final nameWithoutExtension = sanitizedFileName.replaceAll(
          extension,
          '',
        );
        filePath =
            '${directory.path}/$nameWithoutExtension ($counter)$extension';
        file = File(filePath);
        counter++;
      }

      // Tải file từ URL
      final response = await http.get(Uri.parse(url));

      // Kiểm tra phản hồi HTTP
      if (response.statusCode == 200) {
        // Kiểm tra Content-Type để đảm bảo là file hợp lệ
        final contentType = response.headers['content-type'];
        if (contentType == null || !contentType.contains('application')) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('File không hợp lệ')));
          return;
        }

        // Lưu file
        await file.writeAsBytes(response.bodyBytes);

        // Hiển thị thông báo thành công
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('File đã được lưu vào thư mục Tải xuống'),
            action: SnackBarAction(
              label: 'Mở',
              onPressed: () {
                // TODO: Thêm logic mở file (có thể dùng package open_file)
              },
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi khi tải file: ${response.statusCode}')),
        );
      }
    } on SocketException {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không có kết nối internet')),
      );
    } on HttpException {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lỗi khi kết nối đến server')),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Lỗi không xác định: $e')));
      debugPrint('Lỗi tải file: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: CustomHistoryAppBar(),
      body: Stack(
        children: [
          Column(
            children: [
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 8.0,
                ),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Tìm kiếm lịch sử...',
                    prefixIcon: Icon(
                      Icons.search,
                      color: isDarkTheme ? Colors.white70 : Colors.black54,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20.0),
                      borderSide: BorderSide(
                        color: Color(0xFFADD8E6), // Màu viền khi không focus
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20.0),
                      borderSide: BorderSide(
                        color: Color(
                          0xFFADD8E6,
                        ), // Màu viền khi focus (ví dụ: xanh dương đậm)
                        width: 3.0,
                      ),
                    ),
                    filled: true,
                    fillColor:
                        isDarkTheme ? Colors.grey[800] : Colors.grey[200],
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  ),
                  style: GoogleFonts.beVietnamPro(
                    color: isDarkTheme ? Colors.white : Colors.black,
                  ),
                ),
              ),
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
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }
                        if (snapshot.hasError) {
                          return Center(
                            child: Text('Error: ${snapshot.error}'),
                          );
                        }
                        final history = _filterEntries(
                          snapshot.data ?? [],
                          _searchQuery,
                          'my_songs',
                        );
                        if (history.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.format_list_numbered,
                                      size: 24,
                                      color:
                                          isDarkTheme
                                              ? Colors.white70
                                              : Colors.black87,
                                    ),
                                    Icon(
                                      Icons.music_note,
                                      size: 40,
                                      color:
                                          isDarkTheme
                                              ? Colors.white70
                                              : Colors.black87,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  'Danh sách rỗng',
                                  style: GoogleFonts.beVietnamPro(
                                    fontSize: 16,
                                    color:
                                        isDarkTheme
                                            ? Colors.white70
                                            : Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }
                        return ListView.builder(
                          itemCount: history.length,
                          itemBuilder: (context, index) {
                            final entry = history[index];
                            return Card(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              elevation: 0,
                              color:
                                  isDarkTheme ? Colors.grey[850] : Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10.0),
                                side: BorderSide(
                                  color: Color(0xFFADD8E6), // màu viền
                                  width: 2.0, // độ dày viền
                                ),
                              ),
                              child: Theme(
                                data: Theme.of(context).copyWith(
                                  splashFactory:
                                      NoSplash
                                          .splashFactory, // Disable ripple effect
                                ),
                                child: ListTile(
                                  onTap: () {
                                    if (entry.fileUrl != null) {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder:
                                              (context) => MusicPlayScreen(
                                                fileUrl: entry.fileUrl,
                                                textPromptController:
                                                    TextEditingController(
                                                      text: '',
                                                    ),
                                              ),
                                        ),
                                      );
                                    } else {
                                      _showLyricsDialog(entry);
                                    }
                                  },
                                  title: Text(
                                    entry.fileUrl != null
                                        ? ' ${entry.key}'
                                        : 'Song Lyrics',
                                    style: GoogleFonts.beVietnamPro(
                                      fontWeight: FontWeight.bold,
                                      color:
                                          isDarkTheme
                                              ? Colors.white
                                              : Colors.black,
                                    ),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Thời gian: ${_formatDate(entry.date)}',
                                        style: GoogleFonts.beVietnamPro(
                                          color:
                                              isDarkTheme
                                                  ? Colors.white70
                                                  : Colors.black87,
                                        ),
                                      ),
                                    ],
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: Icon(
                                          Icons.download,
                                          color: entry.fileUrl == null
                                              ? Colors.grey
                                              : (isDarkTheme ? Colors.blue[300] : Colors.blue),
                                        ),
                                        onPressed: entry.fileUrl == null
                                            ? null
                                            : () => _downloadFile(entry.fileUrl!, entry.key),
                                        tooltip: 'Download',
                                      ),
                                      IconButton(
                                        icon: Icon(
                                          Icons.delete,
                                          color:
                                              isDarkTheme
                                                  ? Colors.red[300]
                                                  : Colors.red,
                                        ),
                                        onPressed:
                                            () => _deleteEntry(
                                              'favorites',
                                              entry.key,
                                            ),
                                      ),
                                    ],
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
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }
                        if (snapshot.hasError) {
                          return Center(
                            child: Text('Error: ${snapshot.error}'),
                          );
                        }
                        final history = _filterEntries(
                          snapshot.data ?? [],
                          _searchQuery,
                          'favorites',
                        );
                        if (history.isEmpty) {
                          if (history.isEmpty) {
                            return Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.format_list_numbered,
                                        size: 24,
                                        color:
                                            isDarkTheme
                                                ? Colors.white70
                                                : Colors.black87,
                                      ),
                                      Icon(
                                        Icons.music_note,
                                        size: 40,
                                        color:
                                            isDarkTheme
                                                ? Colors.white70
                                                : Colors.black87,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    'Danh sách rỗng',
                                    style: GoogleFonts.beVietnamPro(
                                      fontSize: 16,
                                      color:
                                          isDarkTheme
                                              ? Colors.white70
                                              : Colors.black87,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }
                        }
                        return ListView.builder(
                          itemCount: history.length,
                          itemBuilder: (context, index) {
                            final entry = history[index];
                            return Card(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              elevation: 0,
                              color:
                                  isDarkTheme ? Colors.grey[850] : Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10.0),
                                side: BorderSide(
                                  color: Color(0xFFADD8E6), // màu viền
                                  width: 2.0, // độ dày viền
                                ),
                              ),
                              child: Theme(
                                data: Theme.of(context).copyWith(
                                  splashFactory:
                                      NoSplash
                                          .splashFactory, // Disable ripple effect
                                ),
                                child: ListTile(
                                  onTap: () => _showLyricsDialog(entry),
                                  title: Text(
                                    'Song Lyrics',
                                    style: GoogleFonts.beVietnamPro(
                                      fontWeight: FontWeight.bold,
                                      color:
                                          isDarkTheme
                                              ? Colors.white
                                              : Colors.black,
                                    ),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      if (entry.language.isNotEmpty)
                                        Text(
                                          'Ngôn ngữ: ${entry.language}',
                                          style: GoogleFonts.beVietnamPro(
                                            color:
                                                isDarkTheme
                                                    ? Colors.white70
                                                    : Colors.black87,
                                          ),
                                        ),
                                      if (entry.theme.isNotEmpty)
                                        Text(
                                          'Chủ đề: ${entry.theme}',
                                          style: GoogleFonts.beVietnamPro(
                                            color:
                                                isDarkTheme
                                                    ? Colors.white70
                                                    : Colors.black87,
                                          ),
                                        ),
                                      if (entry.tags.isNotEmpty)
                                        Text(
                                          'Thể loại: ${entry.tags}',
                                          style: GoogleFonts.beVietnamPro(
                                            color:
                                                isDarkTheme
                                                    ? Colors.white70
                                                    : Colors.black87,
                                          ),
                                        ),
                                      Text(
                                        'Thời gian tạo: ${_formatDate(entry.date)}',
                                        style: GoogleFonts.beVietnamPro(
                                          color:
                                              isDarkTheme
                                                  ? Colors.white70
                                                  : Colors.black87,
                                        ),
                                      ),
                                    ],
                                  ),
                                  trailing: IconButton(
                                    icon: Icon(
                                      Icons.delete,
                                      color:
                                          isDarkTheme
                                              ? Colors.red[300]
                                              : Colors.red,
                                    ),
                                    onPressed:
                                        () => _deleteEntry(
                                          'favorites',
                                          entry.key,
                                        ),
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
                  bool isFavoritesEmpty =
                      favoritesSnapshot.data?.isEmpty ?? true;

                  print('Current Tab Index: $_currentTabIndex');
                  print(
                    'isMySongsEmpty: $isMySongsEmpty, isFavoritesEmpty: $isFavoritesEmpty',
                  );

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
                              final appState = Provider.of<MyAppState>(
                                context,
                                listen: false,
                              );
                              if (_currentTabIndex == 0) {
                                print('Navigating to HomeScreen (index 0)');
                                appState.setSelectedIndex(0);
                              } else {
                                print(
                                  'Navigating to LyricsScreen (index 1) from HistoryScreen',
                                );
                                appState.setSelectedIndex(1);
                              }
                            },
                            backgroundColor: Colors.transparent,
                            elevation: 0,
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors:
                                      isDarkTheme
                                          ? [
                                            Colors.blueGrey[600]!,
                                            Colors.blueGrey[800]!,
                                          ]
                                          : [
                                            const Color(0xFF40C4FF),
                                            const Color(0xFF00B7A8),
                                          ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                              ),
                              child: Icon(
                                Icons.add,
                                color:
                                    isDarkTheme ? Colors.white70 : Colors.white,
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
      backgroundColor: isDarkTheme ? Colors.black : Colors.white,
    );
  }
}
