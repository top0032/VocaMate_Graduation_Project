import 'package:flutter/material.dart';
import '../models/theme_model.dart';
import '../services/theme_service.dart';
import 'quiz_page.dart';
import '../theme.dart';

class QuizThemeSelectionScreen extends StatefulWidget {
  const QuizThemeSelectionScreen({super.key});

  @override
  State<QuizThemeSelectionScreen> createState() => _QuizThemeSelectionScreenState();
}

class _QuizThemeSelectionScreenState extends State<QuizThemeSelectionScreen> {
  final ThemeService _themeService = ThemeService();
  Future<List<ThemeModel>>? _themesFuture;

  @override
  void initState() {
    super.initState();
    _loadThemes();
  }

  void _loadThemes() {
    setState(() {
      _themesFuture = _themeService.getThemes();
    });
  }

  void _onThemeSelected(ThemeModel selectedTheme) async {
    // 💡 문제 개수 선택 다이얼로그 표시
    final int? selectedCount = await showDialog<int>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('문제 개수 선택'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text('10 문제'),
                onTap: () => Navigator.of(context).pop(10),
              ),
              ListTile(
                title: const Text('20 문제'),
                onTap: () => Navigator.of(context).pop(20),
              ),
              ListTile(
                title: const Text('모두 풀기'),
                onTap: () => Navigator.of(context).pop(0), // 0을 '모두'로 사용
              ),
            ],
          ),
        );
      },
    );

    if (selectedCount == null) return; // 사용자가 다이얼로그를 그냥 닫은 경우

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => QuizPage(
          theme: selectedTheme,
          numberOfQuestions: selectedCount,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('퀴즈 테마 선택'),
      ),
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
            return const Center(child: Text('등록된 퀴즈 테마가 없습니다.'));
          }

          final themes = snapshot.data!;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: themes.length,
            itemBuilder: (context, index) {
              final theme = themes[index];
              return Card(
                elevation: 2,
                margin: const EdgeInsets.symmetric(vertical: 8.0),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  title: Text(
                    theme.name,
                    style: AppTheme.themeData.textTheme.headlineSmall,
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: () => _onThemeSelected(theme),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
