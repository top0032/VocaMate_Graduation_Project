
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/memo.dart';
import '../theme.dart';

class AddMemoPage extends StatefulWidget {
  const AddMemoPage({super.key});

  @override
  State<AddMemoPage> createState() => _AddMemoPageState();
}

class _AddMemoPageState extends State<AddMemoPage> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();

  Future<void> _saveMemo() async {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('메모 제목을 입력해주세요')));
      return;
    }

    final data = {
      'title': _titleController.text.trim(),
      'content': _contentController.text.trim(),
      'timestamp': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
    };

    final db = FirebaseFirestore.instance;

    // Firestore에 새 문서 추가
    await db.collection('memos').add(data);

    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('새 메모 작성'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: ElevatedButton(
              onPressed: _saveMemo,
              child: const Text('저장'),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: '제목',
              ),
              autofocus: true,
            ),
            const SizedBox(height: 16),
            Expanded(
              child: TextField(
                controller: _contentController,
                decoration: const InputDecoration(
                  labelText: '내용',
                  alignLabelWithHint: true,
                ),
                maxLines: null,
                expands: true,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
