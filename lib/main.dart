import 'package:flutter/material.dart';

import 'screens/announcement_screen.dart';
import 'screens/attendance_screen.dart';
import 'screens/grade_screen.dart';
import 'screens/homework_screen.dart';

void main() {
  runApp(const EduBridgeApp());
}

class EduBridgeApp extends StatelessWidget {
  const EduBridgeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EduBridge',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  final _screens = const [
    AnnouncementScreen(),
    HomeworkScreen(),
    AttendanceScreen(),
    GradeScreen(),
  ];

  static const _titles = ['Зарлал', 'Даалгавар', 'Ирц', 'Дүн'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_selectedIndex]),
        centerTitle: true,
      ),
      body: _screens[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() => _selectedIndex = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.campaign_outlined),
            selectedIcon: Icon(Icons.campaign),
            label: 'Зарлал',
          ),
          NavigationDestination(
            icon: Icon(Icons.assignment_outlined),
            selectedIcon: Icon(Icons.assignment),
            label: 'Даалгавар',
          ),
          NavigationDestination(
            icon: Icon(Icons.fact_check_outlined),
            selectedIcon: Icon(Icons.fact_check),
            label: 'Ирц',
          ),
          NavigationDestination(
            icon: Icon(Icons.grade_outlined),
            selectedIcon: Icon(Icons.grade),
            label: 'Дүн',
          ),
        ],
      ),
    );
  }
}
