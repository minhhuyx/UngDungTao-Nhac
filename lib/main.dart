import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'screens/auth_screen.dart';
import 'screens/home_screen.dart' as home;
import 'screens/history_screen.dart' as history;
import 'screens/settings_screen.dart' as settings;
import 'screens/lyrics_screen.dart' as lyrics;
import 'screens/beat_screen.dart' as beat;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_app_check/firebase_app_check.dart';

// Định nghĩa MyAppState để quản lý trạng thái điều hướng
class MyAppState extends ChangeNotifier {
  int _selectedIndex = 0;

  int get selectedIndex => _selectedIndex;

  void setSelectedIndex(int index) {
    print('Setting selectedIndex to $index');
    _selectedIndex = index;
    notifyListeners();
    print('After notifyListeners, selectedIndex: $_selectedIndex');
  }
}



void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  try {
    await Firebase.initializeApp();
    FirebaseDatabase.instance.setPersistenceEnabled(true);
    FirebaseDatabase.instance.setPersistenceCacheSizeBytes(10000000);
    FirebaseDatabase.instance.databaseURL =
    'https://datn-9fc08-default-rtdb.asia-southeast1.firebasedatabase.app';
    await FirebaseAppCheck.instance.activate(
      webProvider: ReCaptchaV3Provider(dotenv.env['RECAPTCHA_SITE_KEY'] ?? ''),
      androidProvider: AndroidProvider.debug,
      appleProvider: AppleProvider.debug,
    );
    runApp(
      ChangeNotifierProvider(
        create: (context) => MyAppState(),
        child: const MyApp(),
      ),
    );
  } catch (e) {
    print('Firebase initialization failed: $e');
    runApp(ErrorApp(error: 'Firebase initialization failed: $e', onRetry: () => main()));
  }
}

class ErrorApp extends StatelessWidget {
  final String error;
  final VoidCallback? onRetry;

  const ErrorApp({required this.error, this.onRetry, Key? key}) : super(key: key);

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

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _wasPreviouslyLoggedIn = false;

  final ThemeData _lightTheme = ThemeData(
    primarySwatch: Colors.grey,
    brightness: Brightness.light,
    scaffoldBackgroundColor: Colors.white,
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFFADD8E6),
      foregroundColor: Colors.black,
    ),
  );

  final ThemeData _darkTheme = ThemeData(
    primarySwatch: Colors.grey,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: Colors.black,
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.black,
      foregroundColor: Colors.white,
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

        final isLoggedIn = authSnapshot.hasData;
        if (isLoggedIn && !_wasPreviouslyLoggedIn) {
          final appState = Provider.of<MyAppState>(context, listen: false);
          appState.setSelectedIndex(0);
        }
        _wasPreviouslyLoggedIn = isLoggedIn;

        if (isLoggedIn) {
          return StreamBuilder<DatabaseEvent>(
            stream: FirebaseDatabase.instance
                .ref('settings/${authSnapshot.data!.uid}/is_dark_theme')
                .onValue,
            builder: (context, themeSnapshot) {
              bool isDarkTheme = false;
              if (themeSnapshot.hasData && themeSnapshot.data!.snapshot.value != null) {
                isDarkTheme = themeSnapshot.data!.snapshot.value as bool;
              }

              return MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: _lightTheme,
                darkTheme: _darkTheme,
                themeMode: isDarkTheme ? ThemeMode.dark : ThemeMode.light,
                home: Consumer<MyAppState>(
                  builder: (context, appState, child) {
                    print('Building Scaffold with selectedIndex: ${appState.selectedIndex}');
                    final List<Widget> screens = [
                      const home.HomeScreen(),
                      const lyrics.LyricsScreen(),
                      const beat.BeatScreen(),
                      history.HistoryScreen(
                        onNavigate: (index) {
                          print('HistoryScreen onNavigate called with index: $index');
                          appState.setSelectedIndex(index);
                        },
                      ),
                      const settings.SettingsScreen(),

                    ];

                    print('Rendering screen at index: ${appState.selectedIndex}, Screen: ${screens[appState.selectedIndex].runtimeType}');

                    return Scaffold(
                      body: screens[appState.selectedIndex],
                      bottomNavigationBar: Theme(
                        data: Theme.of(context).copyWith(
                          splashColor: Colors.transparent,      // Tắt hiệu ứng sóng nước
                          highlightColor: Colors.transparent,   // Tắt hiệu ứng khi nhấn giữ
                        ),
                        child: BottomNavigationBar(
                          currentIndex: appState.selectedIndex,
                          onTap: (index) {
                            appState.setSelectedIndex(index);
                          },
                          type: BottomNavigationBarType.fixed,
                          selectedItemColor: isDarkTheme ? const Color(0xFFADD8E6) : const Color(0xFFADD8E6),
                          unselectedItemColor: isDarkTheme ? Colors.white70 : Colors.black45,
                          items: const [
                            BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Trang Chủ'),
                            BottomNavigationBarItem(icon: Icon(Icons.music_note), label: 'Tạo lời nhạc'),
                            BottomNavigationBarItem(icon: Icon(Icons.piano), label: 'Beat'),
                            BottomNavigationBarItem(icon: Icon(Icons.history), label: 'Lịch Sử'),
                            BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Cài đặt'),

                          ],
                        ),
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
          themeMode: ThemeMode.light,
          home: const AuthScreen(),
        );
      },
    );
  }
}