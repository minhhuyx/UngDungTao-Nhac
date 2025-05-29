import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'lyrics_screen.dart';
import 'history_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({Key? key}) : super(key: key);

  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  List<Widget> get _widgetOptions => <Widget>[
    HomeScreen(),
    LyricsScreen(),
    HistoryScreen(
      onNavigate: (index) {
        setState(() {
          _selectedIndex = index;
        });
      },
    ),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _widgetOptions,
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Trang Chủ',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.music_note),
            label: 'Tạo Lời',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history),
            label: 'Lịch Sử',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.blue[300],
        onTap: _onItemTapped,
      ),
    );
  }
}