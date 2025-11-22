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

  // 💡 테마 추가 함수
  void _addTheme() async {
    if (_idController.text.isEmpty || _nameController.text.isEmpty) return;

    // 문서 ID를 직접 지정해서 생성
    await FirebaseFirestore.instance
        .collection('themes')
        .doc(_idController.text)
        .set({
          'name': _nameController.text,
          'createdAt': FieldValue.serverTimestamp(),
        });

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('테마가 추가되었습니다.')));
      _idController.clear();
      _nameController.clear();
    }
  }

  // 💡 테마 삭제 함수
  void _deleteTheme(String docId) async {
    await FirebaseFirestore.instance.collection('themes').doc(docId).delete();
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('테마가 삭제되었습니다.')));
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
              decoration: const InputDecoration(labelText: '테마 ID (예: T006)'),
            ),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: '테마 이름 (예: 여행)'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          ElevatedButton(onPressed: _addTheme, child: const Text('저장')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('테마 관리')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('themes').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting)
            return const Center(child: CircularProgressIndicator());
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty)
            return const Center(child: Text('등록된 테마가 없습니다.'));

          final docs = snapshot.data!.docs;

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              final docId = docs[index].id;

              return ListTile(
                leading: CircleAvatar(child: Text(docId.substring(0, 1))),
                title: Text(data['name'] ?? ''),
                subtitle: Text('ID: $docId'),
                trailing: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _deleteTheme(docId),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}
