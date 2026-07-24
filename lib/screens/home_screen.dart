import 'package:flutter/material.dart';

import '../state/app_store.dart';
import 'announcement_screen.dart';
import 'attendance_screen.dart';
import 'class_dashboard_screen.dart';
import 'grade_screen.dart';
import 'homework_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.selectedClass,
    required this.store,
  });

  final String selectedClass;
  final AppStore store;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  late final List<Widget> _screens;

  static const _titles = ['Нүүр', 'Зарлал', 'Даалгавар', 'Ирц', 'Дүн'];

  @override
  void initState() {
    super.initState();
    final selectedClass = widget.selectedClass;
    final store = widget.store;
    _screens = [
      ClassDashboardScreen(selectedClass: selectedClass, store: store),
      AnnouncementScreen(selectedClass: selectedClass, store: store),
      HomeworkScreen(selectedClass: selectedClass, store: store),
      AttendanceScreen(selectedClass: selectedClass, store: store),
      GradeScreen(selectedClass: selectedClass, store: store),
    ];
  }

  void _changeClass() {
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_selectedIndex]),
        centerTitle: true,
        actions: [
          if (_selectedIndex != 0)
            TextButton(
              onPressed: _changeClass,
              child: const Text('Анги солих'),
            ),
        ],
      ),
      body: IndexedStack(index: _selectedIndex, children: _screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() => _selectedIndex = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Нүүр',
          ),
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
