import 'package:flutter/material.dart';

import 'screens/class_selection_screen.dart';
import 'state/app_store.dart';

void main() {
  runApp(EduBridgeApp(store: AppStore()));
}

class EduBridgeApp extends StatelessWidget {
  const EduBridgeApp({super.key, required this.store});

  final AppStore store;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EduBridge',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: ClassSelectionScreen(store: store),
    );
  }
}
