// lib/screens/main_screen.dart

import 'package:flutter/material.dart';
import 'theme_selection_screen.dart'; // 💡 이동할 테마 선택 화면 import

class MainScreen extends StatelessWidget {
  const MainScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('VocaMate 홈')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              '로그인 성공! 이제 단어 학습을 시작합니다.',
              style: TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 50),

            // 💡 '학습하기' 메뉴 버튼 (ElevatedButton)
            ElevatedButton(
              onPressed: () {
                // 학습하기 메뉴 클릭 시 테마 선택 화면으로 이동
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ThemeSelectionScreen(),
                  ),
                );
              },
              child: const Text('학습하기', style: TextStyle(fontSize: 20)),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(200, 60),
                backgroundColor: Colors.blueGrey,
                foregroundColor: Colors.white,
              ),
            ),
            // 💡 여기에는 다른 메뉴 버튼이 추가될 수 있습니다.
          ],
        ),
      ),
    );
  }
}
