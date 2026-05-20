import 'package:flutter/material.dart';
import 'views/home_screen.dart';

void main() => runApp(const JoshSecurityApp());

class JoshSecurityApp extends StatelessWidget {
  const JoshSecurityApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Josh Security',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xff0d1117),
      ),
      home: const HomeScreen(),
    );
  }
}