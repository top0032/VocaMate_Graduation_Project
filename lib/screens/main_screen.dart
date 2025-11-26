import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'theme_selection_screen.dart'; // 이동할 테마 선택 화면
import 'memo_list_page.dart'; // 이동할 메모 목록 화면
import 'quiz_theme_selection_screen.dart'; // 💡 퀴즈 테마 선택 화면
import 'admin/admin_screen.dart'; // 💡 관리자 대시보드 화면
import 'favorites_screen.dart'; // 💡 [추가] 나만의 단어장 화면 import
import '../theme.dart';
import 'auth/auth_check_screen.dart'; // 로그아웃 후 이동할 화면

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _checkAdminStatus();
  }

  // 💡 관리자 권한 확인 함수
  Future<void> _checkAdminStatus() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (userDoc.exists && userDoc.data() != null) {
          final data = userDoc.data() as Map<String, dynamic>;
          // Firestore의 'role' 필드가 'admin'인지 확인
          if (data['role'] == 'admin') {
            if (mounted) {
              setState(() {
                _isAdmin = true;
              });
            }
          }
        }
      } catch (e) {
        print('관리자 확인 중 오류 발생: $e');
      }
    }
  }

  // 로그아웃 로직
  void _logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const AuthCheckScreen()),
      (route) => false,
    );
  }

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
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _logout(context),
            tooltip: '로그아웃',
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

                  // 💡 [추가됨] '나만의 단어장' 메뉴 카드
                  MenuCard(
                    title: '나만의 단어장',
                    icon: Icons.star,
                    iconColor: Colors.amber, // 별 색상 강조
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const FavoritesScreen(),
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

                  // 💡 퀴즈 메뉴
                  MenuCard(
                    title: '퀴즈 풀기',
                    icon: Icons.quiz,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              const QuizThemeSelectionScreen(),
                        ),
                      );
                    },
                  ),

                  // 💡 관리자일 때만 보이는 '관리자 페이지' 메뉴 카드
                  if (_isAdmin)
                    MenuCard(
                      title: '관리자 페이지',
                      icon: Icons.admin_panel_settings,
                      iconColor: Colors.redAccent,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const AdminScreen(),
                          ),
                        );
                      },
                    ),
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
  final Color? iconColor; // 💡 아이콘 색상 커스터마이징 추가

  const MenuCard({
    super.key,
    required this.title,
    required this.icon,
    required this.onTap,
    this.iconColor,
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
            Icon(icon, size: 48, color: iconColor ?? AppTheme.primaryColor),
            const SizedBox(height: 16),
            Text(title, style: AppTheme.themeData.textTheme.headlineSmall),
          ],
        ),
      ),
    );
  }
}
