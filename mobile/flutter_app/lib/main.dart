import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'screens/home_screen.dart';
import 'db/database.dart';

final databaseProvider = Provider<AppDatabase>((ref) => AppDatabase());

void main() {
  runApp(const ProviderScope(child: RiceAgentApp()));
}

class RiceAgentApp extends StatelessWidget {
  const RiceAgentApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RiceAgent',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
