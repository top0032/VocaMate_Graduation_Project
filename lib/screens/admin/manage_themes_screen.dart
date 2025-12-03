import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ManageThemesScreen extends StatefulWidget {
  const ManageThemesScreen({super.key});

  @override
  State<ManageThemesScreen> createState() => _ManageThemesScreenState();
}

class _ManageThemesScreenState extends State<ManageThemesScreen> {
  final TextEditingController _idController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  bool _isLoading = false; // 💡 로딩 상태 변수 추가

  // 💡 메모리 누수 방지를 위한 dispose 추가
  @override
  void dispose() {
    _idController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  // 💡 테마 추가 함수 (에러 처리 강화)
  void _addTheme() async {
    if (_idController.text.trim().isEmpty ||
        _nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('ID와 이름을 모두 입력해주세요.')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 문서 ID를 직접 지정해서 생성 (중복 방지 및 관리 용이)
      await FirebaseFirestore.instance
          .collection('themes')
          .doc(_idController.text.trim())
          .set({
            'name': _nameController.text.trim(),
            'createdAt': FieldValue.serverTimestamp(),
          });

      if (mounted) {
        Navigator.pop(context); // 다이얼로그 닫기
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('테마가 성공적으로 추가되었습니다.')));
        _idController.clear();
        _nameController.clear();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('테마 추가 실패: $e')));
        print("테마 추가 에러: $e");
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 💡 테마 삭제 함수 (에러 처리 강화)
  void _deleteTheme(String docId) async {
    try {
      await FirebaseFirestore.instance.collection('themes').doc(docId).delete();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('테마가 삭제되었습니다.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('삭제 실패: $e')));
      }
    }
  }

  void _showAddDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('새 테마 추가'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _idController,
              decoration: const InputDecoration(labelText: '테마 ID (예: daily)'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: '테마 이름 (예: 일상)'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: _isLoading ? null : _addTheme,
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('저장'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('테마 관리'),
        backgroundColor: Colors.redAccent, // 관리자 페이지 느낌 강조
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('themes').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('데이터 로드 오류: ${snapshot.error}'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('등록된 테마가 없습니다.'));
          }

          final docs = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              final docId = docs[index].id;

              return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.redAccent.withOpacity(0.1),
                    child: Text(
                      docId.isNotEmpty ? docId.substring(0, 1) : '?',
                      style: const TextStyle(color: Colors.redAccent),
                    ),
                  ),
                  title: Text(
                    data['name'] ?? '이름 없음',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text('ID: $docId'),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _deleteTheme(docId),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDialog,
        backgroundColor: Colors.redAccent,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
