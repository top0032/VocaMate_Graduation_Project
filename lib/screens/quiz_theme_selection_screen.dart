import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/theme_model.dart';
import '../models/word_model.dart';
import '../services/theme_service.dart';
import 'quiz_page.dart';
import 'quiz_stats_screen.dart'; // 1. 통계 화면 import
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

  Future<int?> _showQuestionCountDialog() {
    return showDialog<int>(
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
  }

  void _onMyVocabularySelected() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('퀴즈를 만들려면 로그인이 필요합니다.')),
      );
      return;
    }

    final int? selectedCount = await _showQuestionCountDialog();
    if (selectedCount == null) return;

    final favoritesSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('favorites')
        .get();

    if (favoritesSnapshot.docs.length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('퀴즈를 만들려면 최소 4개 이상의 단어를 즐겨찾기해야 합니다.')),
      );
      return;
    }

    final favoriteWords = favoritesSnapshot.docs
        .map((doc) => WordModel.fromMap(doc.data(), doc.id))
        .toList();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => QuizPage(
          words: favoriteWords,
          numberOfQuestions: selectedCount,
          quizTitle: '나만의 단어장 퀴즈',
        ),
      ),
    );
  }

  void _onThemeSelected(ThemeModel selectedTheme) async {
    final int? selectedCount = await _showQuestionCountDialog();
    if (selectedCount == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => QuizPage(
          theme: selectedTheme,
          numberOfQuestions: selectedCount,
          quizTitle: '${selectedTheme.name} 퀴즈',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('퀴즈 풀기'),
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
          const int extraItems = 2; // 2. '통계'와 '나만의 단어장' 카드

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: themes.length + extraItems,
            itemBuilder: (context, index) {
              // 3. '퀴즈 통계' 카드
              if (index == 0) {
                return Card(
                  elevation: 2,
                  margin: const EdgeInsets.symmetric(vertical: 8.0),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    leading: const Icon(Icons.bar_chart, color: Colors.blueGrey),
                    title: Text(
                      '퀴즈 통계 보기',
                      style: AppTheme.themeData.textTheme.headlineSmall,
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const QuizStatsScreen()),
                      );
                    },
                  ),
                );
              }

              // '나만의 단어장' 카드
              if (index == 1) { // 3. 인덱스 1로 변경
                return Card(
                  elevation: 2,
                  margin: const EdgeInsets.symmetric(vertical: 8.0),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  color: Colors.white,
                  child: ListTile(
                    leading: const Icon(Icons.star, color: Colors.amber),
                    title: Text(
                      '나만의 단어장',
                      style: AppTheme.themeData.textTheme.headlineSmall?.copyWith(
                        color: Colors.amber,
                      ),
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios, color: Colors.amber),
                    onTap: _onMyVocabularySelected,
                  ),
                );
              }

              // 4. 나머지 테마들 (인덱스 조정)
              final theme = themes[index - extraItems];
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

