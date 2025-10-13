// lib/screens/theme_selection_screen.dart

import 'package:flutter/material.dart';
import '../models/theme_model.dart';
import '../services/theme_service.dart';
import 'learning_screen.dart';

class ThemeSelectionScreen extends StatefulWidget {
  const ThemeSelectionScreen({super.key});

  @override
  State<ThemeSelectionScreen> createState() => _ThemeSelectionScreenState();
}

class _ThemeSelectionScreenState extends State<ThemeSelectionScreen> {
  final ThemeService _themeService = ThemeService();
  Future<List<ThemeModel>>? _themesFuture;

  @override
  void initState() {
    super.initState();
    _themesFuture = _themeService.getThemes(); // 화면 로드 시 테마 목록 로드 시작
  }

  // 💡 테마 선택 시 학습 화면으로 이동
  void _onThemeSelected(ThemeModel selectedTheme) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LearningScreen(theme: selectedTheme),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('테마 선택')),
      body: FutureBuilder<List<ThemeModel>>(
        future: _themesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('테마 로드 오류: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('등록된 학습 테마가 없습니다.'));
          }

          final themes = snapshot.data!;

          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2, // 한 줄에 2개의 테마 카드
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.5,
            ),
            itemCount: themes.length,
            itemBuilder: (context, index) {
              final theme = themes[index];
              return InkWell(
                onTap: () => _onThemeSelected(theme),
                child: Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      theme.name,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.blueGrey,
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
