import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'manage_words_screen.dart';
import 'manage_themes_screen.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  int _userCount = 0;
  int _wordCount = 0;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  // 💡 대시보드용 통계 데이터 로드 (문서 개수 세기)
  Future<void> _loadStats() async {
    // 참고: 실제 서비스에서는 카운터용 별도 문서를 두는 것이 비용 효율적입니다.
    // 여기서는 졸업작품 규모이므로 직접 count를 가져옵니다.
    final userSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .count()
        .get();
    final wordSnapshot = await FirebaseFirestore.instance
        .collection('words')
        .count()
        .get();

    if (mounted) {
      setState(() {
        _userCount = userSnapshot.count ?? 0;
        _wordCount = wordSnapshot.count ?? 0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('관리자 대시보드'),
        backgroundColor: Colors.redAccent,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '📊 서비스 현황',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 15),
            Row(
              children: [
                _buildStatCard('총 사용자', '$_userCount명', Colors.orange),
                const SizedBox(width: 15),
                _buildStatCard('총 단어', '$_wordCount개', Colors.blue),
              ],
            ),
            const SizedBox(height: 40),
            const Text(
              '🛠️ 콘텐츠 관리',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 15),

            _buildMenuTile(
              icon: Icons.library_books,
              title: '단어 관리',
              subtitle: '단어 추가, 수정 및 삭제',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ManageWordsScreen(),
                  ),
                );
              },
            ),
            _buildMenuTile(
              icon: Icons.category,
              title: '테마 관리',
              subtitle: '학습 테마(카테고리) 관리',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ManageThemesScreen(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String count, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: color, width: 2),
        ),
        child: Column(
          children: [
            Text(
              count,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              title,
              style: const TextStyle(fontSize: 16, color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 15),
      elevation: 3,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.grey.shade200,
          child: Icon(icon, color: Colors.black87),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }
}
