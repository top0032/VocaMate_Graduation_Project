// lib/pages/edit_memo_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/memo.dart';

class EditMemoPage extends StatefulWidget {
  final Memo memo;
  final Function(Memo) onSave;
  final VoidCallback onDelete;

  // const 키워드가 제거된 생성자
  EditMemoPage({
    super.key,
    required this.memo,
    required this.onSave,
    required this.onDelete,
  });

  @override
  State<EditMemoPage> createState() => _EditMemoPageState();
}

class _EditMemoPageState extends State<EditMemoPage> {
  late TextEditingController _titleController;
  late TextEditingController _contentController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.memo.title);
    _contentController = TextEditingController(text: widget.memo.content);
  }

  Future<bool> _onWillPop() async {
    final hasChanges = widget.memo.title != _titleController.text.trim() ||
        widget.memo.content != _contentController.text.trim();

    if (!hasChanges) {
      return true; // 변경사항이 없으면 뒤로가기 허용
    }

    // 변경사항이 있으면 대화상자 표시
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('변경사항 저장'),
        content: const Text('변경사항을 저장하고 나가시겠습니까?'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop('cancel'), // 취소
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop('discard'), // 저장 안함
            child: const Text('저장 안함'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop('save'), // 저장
            child: const Text('저장'),
          ),
        ],
      ),
    );

    if (result == 'save') {
      await _saveMemo(); // 저장 및 pop 처리
      return false; // WillPopScope는 pop을 수행하지 않음
    }

    return result == 'discard'; // 'discard'일 때만 pop 허용
  }

  Future<void> _saveMemo() async {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('메모 제목을 입력해주세요')));
      return;
    }

    // 🚨 여기서 ID 참조 오류를 수정했습니다.
    final updatedMemo = Memo(
      id: widget.memo.id, // 부모 위젯의 memo 객체에서 ID를 가져옵니다.
      title: _titleController.text.trim(),
      content: _contentController.text.trim(),
      createdAt: widget.memo.createdAt, // 생성일자(createdAt) 보존
    );

    widget.onSave(updatedMemo);

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  void _deleteMemo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('삭제 확인'),
        content: const Text('정말 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              widget.onDelete();

              Navigator.of(context).pop();
              Navigator.of(context).pop();
            },
            child: const Text('삭제', style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        appBar: AppBar(
          title: SizedBox(
            height: 40,
            child: TextField(
              controller: _titleController,
              style: const TextStyle(color: Colors.black, fontSize: 20),
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText: '제목 없음',
              ),
            ),
          ),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          actions: [
            TextButton(
              onPressed: _saveMemo,
              child: const Text(
                '저장',
                style: TextStyle(color: Colors.black, fontSize: 16),
              ),
            ),
            TextButton(
              onPressed: _deleteMemo,
              child: const Text(
                '삭제',
                style: TextStyle(color: Colors.black, fontSize: 16),
              ),
            ),
          ],
        ),
        body: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => FocusScope.of(context).requestFocus(FocusNode()),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _contentController,
              style: const TextStyle(fontSize: 16),
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText: '메모 내용을 입력하세요',
              ),
              maxLines: null,
              expands: true,
              keyboardType: TextInputType.multiline,
              autofocus: true,
            ),
          ),
        ),
      ),
    );
  }
}
