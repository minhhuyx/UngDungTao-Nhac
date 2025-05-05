import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'screens/auth_screen.dart';
import 'screens/home_screen.dart' as home;
import 'screens/history_screen.dart' as history;
import 'screens/settings_screen.dart' as settings;
import 'screens/account_screen.dart' as account;
import 'screens/lyrics_screen.dart' as lyrics;
import 'package:flutter_dotenv/flutter_dotenv.dart';
// Định nghĩa MyAppState để quản lý trạng thái điều hướng
class MyAppState extends ChangeNotifier {
  int _selectedIndex = 0;

  int get selectedIndex => _selectedIndex;

  void setSelectedIndex(int index) {
    print('Setting selectedIndex to $index'); // Debug
    _selectedIndex = index;
    notifyListeners();
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Tải file .env
  await dotenv.load(fileName: ".env");

  // Khởi tạo Firebase
  try {
    await Firebase.initializeApp();

    // Bật persistence cho Realtime Database (hỗ trợ offline)
    FirebaseDatabase.instance.setPersistenceEnabled(true);
    // Thiết lập kích thước cache
    FirebaseDatabase.instance.setPersistenceCacheSizeBytes(10000000); // 10MB
    // Chỉ định database URL
    FirebaseDatabase.instance.databaseURL =
    'https://datn-9fc08-default-rtdb.asia-southeast1.firebasedatabase.app';

    // Bao bọc ứng dụng trong ChangeNotifierProvider để cung cấp MyAppState
    runApp(
      ChangeNotifierProvider(
        create: (context) => MyAppState(),
        child: const MyApp(),
      ),
    );
  } catch (e) {
    print('Firebase initialization failed: $e');
    runApp(ErrorApp(
      error: 'Firebase initialization failed: $e',
      onRetry: () {
        main(); // Thử khởi tạo lại
      },
    ));
  }
}

// Widget hiển thị lỗi nếu Firebase khởi tạo thất bại
class ErrorApp extends StatelessWidget {
  final String error;
  final VoidCallback? onRetry;

  const ErrorApp({required this.error, this.onRetry, Key? key})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(error, style: const TextStyle(color: Color(0xFFFFC0CB))),
              const SizedBox(height: 20),
              if (onRetry != null)
                ElevatedButton(
                  onPressed: onRetry,
                  child: const Text('Thử lại'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// Ứng dụng chính với BottomNavigationBar để điều hướng
class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _wasPreviouslyLoggedIn = false;

  // Định nghĩa Light Theme
  final ThemeData _lightTheme = ThemeData(
    primarySwatch: Colors.pink,
    brightness: Brightness.light,
    scaffoldBackgroundColor: Colors.white,
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFFFFC0CB),
      foregroundColor: Colors.black87,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        side: const BorderSide(color: Colors.black87, width: 1.0),
        backgroundColor: const Color(0xFFFFC0CB),
        foregroundColor: Colors.black87,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: Colors.black87,
      ),
    ),
  );

  // Định nghĩa Dark Theme với tất cả văn bản màu trắng
  final ThemeData _darkTheme = ThemeData(
    primarySwatch: Colors.pink,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: Colors.grey[900],
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.grey[850],
      foregroundColor: Colors.white,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        side: const BorderSide(color: Colors.white70, width: 1.0),
        backgroundColor: Colors.pink[700],
        foregroundColor: Colors.white, // Văn bản trong nút màu trắng
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: Colors.white, // Văn bản trong TextButton màu trắng
      ),
    ),
    textTheme: const TextTheme(
      bodyMedium: TextStyle(color: Colors.white), // Văn bản thông thường
      bodyLarge: TextStyle(color: Colors.white), // Văn bản lớn hơn
      titleLarge: TextStyle(color: Colors.white), // Tiêu đề lớn (như AppBar)
      titleMedium: TextStyle(color: Colors.white), // Tiêu đề trung bình
      titleSmall: TextStyle(color: Colors.white), // Tiêu đề nhỏ
      labelLarge: TextStyle(color: Colors.white), // Nhãn nút
      labelMedium: TextStyle(color: Colors.white), // Nhãn trung bình
      labelSmall: TextStyle(color: Colors.white), // Nhãn nhỏ
    ),
    inputDecorationTheme: InputDecorationTheme(
      labelStyle: TextStyle(color: Colors.white), // Nhãn trong TextField
      hintStyle: TextStyle(color: Colors.white70), // Gợi ý trong TextField
      border: OutlineInputBorder(
        borderSide: BorderSide(color: Colors.white70),
      ),
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(color: Colors.white70),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(color: Colors.white),
      ),
    ),
    dropdownMenuTheme: DropdownMenuThemeData(
      textStyle: TextStyle(color: Colors.white), // Văn bản trong DropdownButton
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.all(Colors.white),
      trackColor: WidgetStateProperty.all(Colors.pink[700]),
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      selectedLabelStyle: TextStyle(color: Colors.white),
      unselectedLabelStyle: TextStyle(color: Colors.white70),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const MaterialApp(
            home: Scaffold(
              body: Center(child: CircularProgressIndicator()),
            ),
          );
        }
        if (authSnapshot.hasError) {
          return MaterialApp(
            home: Scaffold(
              body: Center(child: Text('Error: ${authSnapshot.error}')),
            ),
          );
        }

        // Phát hiện khi người dùng vừa đăng nhập
        final isLoggedIn = authSnapshot.hasData;
        if (isLoggedIn && !_wasPreviouslyLoggedIn) {
          // Đặt lại selectedIndex về 0 (HomeScreen) khi vừa đăng nhập
          final appState = Provider.of<MyAppState>(context, listen: false);
          appState.setSelectedIndex(0);
        }
        _wasPreviouslyLoggedIn = isLoggedIn;

        if (isLoggedIn) {
          // Lắng nghe trạng thái Dark Theme từ Firebase
          return StreamBuilder<DatabaseEvent>(
            stream: FirebaseDatabase.instance
                .ref('settings/${authSnapshot.data!.uid}/is_dark_theme')
                .onValue,
            builder: (context, themeSnapshot) {
              bool isDarkTheme = false;
              if (themeSnapshot.hasData &&
                  themeSnapshot.data!.snapshot.value != null) {
                isDarkTheme = themeSnapshot.data!.snapshot.value as bool;
              }

              return MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: _lightTheme,
                darkTheme: _darkTheme,
                themeMode: isDarkTheme ? ThemeMode.dark : ThemeMode.light,
                home: Consumer<MyAppState>(
                  builder: (context, appState, child) {
                    print(
                        'Building Scaffold with selectedIndex: ${appState.selectedIndex}'); // Debug
                    // Danh sách các màn hình
                    final List<Widget> screens = [
                      const home.HomeScreen(),
                      const lyrics.LyricsScreen(),
                      const history.HistoryScreen(),
                      const settings.SettingsScreen(),
                      const account.AccountScreen(),
                    ];

                    return Scaffold(
                      body: screens[appState.selectedIndex],
                      bottomNavigationBar: BottomNavigationBar(
                        items: const [
                          BottomNavigationBarItem(
                              icon: Icon(Icons.home), label: 'Home'),
                          BottomNavigationBarItem(
                              icon: Icon(Icons.music_note), label: 'Lyrics'),
                          BottomNavigationBarItem(
                              icon: Icon(Icons.history), label: 'History'),
                          BottomNavigationBarItem(
                              icon: Icon(Icons.settings), label: 'Settings'),
                          BottomNavigationBarItem(
                              icon: Icon(Icons.account_circle), label: 'Account'),
                        ],
                        currentIndex: appState.selectedIndex,
                        selectedItemColor: isDarkTheme ? Colors.white : const Color(0xFFFFC0CB),
                        unselectedItemColor: isDarkTheme ? Colors.white70 : Colors.grey,
                        onTap: (index) {
                          appState.setSelectedIndex(index);
                        },
                        type: BottomNavigationBarType.fixed,
                      ),
                    );
                  },
                ),
              );
            },
          );
        }
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: _lightTheme,
          darkTheme: _darkTheme,
          themeMode: ThemeMode.light, // Mặc định là Light Theme khi chưa đăng nhập
          home: const AuthScreen(),
        );
      },
    );
  }
}