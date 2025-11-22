import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ManageWordsScreen extends StatefulWidget {
  const ManageWordsScreen({super.key});

  @override
  State<ManageWordsScreen> createState() => _ManageWordsScreenState();
}

class _ManageWordsScreenState extends State<ManageWordsScreen> {
  // 단어 추가를 위한 컨트롤러
  final TextEditingController _wordController = TextEditingController();
  final TextEditingController _meaningController = TextEditingController();
  final TextEditingController _themeIdController =
      TextEditingController(); // 편의상 ID 직접 입력 (혹은 드롭다운 구현 가능)
  final TextEditingController _levelController = TextEditingController();

  // 💡 단어 추가 함수
  void _addWord() async {
    if (_wordController.text.isEmpty || _themeIdController.text.isEmpty) return;

    await FirebaseFirestore.instance.collection('words').add({
      'word': _wordController.text,
      'meaning': _meaningController.text,
      'themeId': _themeIdController.text,
      'level': _levelController.text,
      'createdAt': FieldValue.serverTimestamp(),
    });

    if (mounted) {
      Navigator.pop(context); // 다이얼로그 닫기
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('단어가 추가되었습니다.')));
      _clearControllers();
    }
  }

  // 💡 단어 삭제 함수
  void _deleteWord(String docId) async {
    await FirebaseFirestore.instance.collection('words').doc(docId).delete();
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('단어가 삭제되었습니다.')));
    }
  }

  void _clearControllers() {
    _wordController.clear();
    _meaningController.clear();
    _themeIdController.clear();
    _levelController.clear();
  }

  void _showAddDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('새 단어 추가'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _wordController,
                decoration: const InputDecoration(
                  labelText: '영단어 (예: Algorithm)',
                ),
              ),
              TextField(
                controller: _meaningController,
                decoration: const InputDecoration(labelText: '뜻 (예: 알고리즘)'),
              ),
              TextField(
                controller: _themeIdController,
                decoration: const InputDecoration(labelText: '테마 ID (예: T005)'),
              ),
              TextField(
                controller: _levelController,
                decoration: const InputDecoration(labelText: '난이도 (예: 고급)'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          ElevatedButton(onPressed: _addWord, child: const Text('저장')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('단어 관리')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('words')
            .orderBy('word')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting)
            return const Center(child: CircularProgressIndicator());
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty)
            return const Center(child: Text('등록된 단어가 없습니다.'));

          final docs = snapshot.data!.docs;

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              final docId = docs[index].id;

              return ListTile(
                title: Text(
                  data['word'] ?? '',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text('${data['meaning']} (테마: ${data['themeId']})'),
                trailing: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _deleteWord(docId),
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
