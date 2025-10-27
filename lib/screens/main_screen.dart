import 'package:flutter/material.dart';
import 'theme_selection_screen.dart'; // 💡 이동할 테마 선택 화면 import
import 'memo_list_page.dart'; // 💡 이동할 메모 목록 화면 import
import '../theme.dart';

class MainScreen extends StatelessWidget {
  const MainScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('VocaMate 홈'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              // TODO: 설정 화면으로 이동
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('안녕하세요!', style: AppTheme.themeData.textTheme.displaySmall),
            const SizedBox(height: 8),
            Text(
              '오늘도 즐겁게 학습해볼까요?',
              style: AppTheme.themeData.textTheme.titleLarge?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 32),
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                children: [
                  MenuCard(
                    title: '단어 학습',
                    icon: Icons.school,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ThemeSelectionScreen(),
                        ),
                      );
                    },
                  ),
                  MenuCard(
                    title: '메모장',
                    icon: Icons.note,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => MemoListPage()),
                      );
                    },
                  ),
                  // TODO: Add more menu items here
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MenuCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback onTap;

  const MenuCard({
    super.key,
    required this.title,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 48, color: AppTheme.primaryColor),
            const SizedBox(height: 16),
            Text(title, style: AppTheme.themeData.textTheme.headlineSmall),
          ],
        ),
      ),
    );
  }
}
