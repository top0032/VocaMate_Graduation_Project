// lib/pages/memo_list_page.dart
// 최종 수정된 목록 페이지 (역순 정렬 제거)

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/memo.dart';
import 'add_memo_page.dart';
import 'edit_memo_page.dart';

// 정렬 방식을 정의하는 enum
enum SortOrder { recent, old, titleAZ }

class MemoListPage extends StatefulWidget {
  MemoListPage({super.key});

  @override
  State<MemoListPage> createState() => _MemoListPageState();
}

class _MemoListPageState extends State<MemoListPage> {
  final db = FirebaseFirestore.instance;
  SortOrder _sortOrder = SortOrder.recent; // 기본 정렬 방식

  // 정렬 방식에 따라 Firestore 쿼리를 동적으로 생성
  Stream<QuerySnapshot<Map<String, dynamic>>> getMemosStream() {
    Query query = db.collection('memos');
    switch (_sortOrder) {
      case SortOrder.recent:
        query = query.orderBy('timestamp', descending: true);
        break;
      case SortOrder.old:
        query = query.orderBy('createdAt', descending: false);
        break;
      case SortOrder.titleAZ:
        query = query.orderBy('title', descending: false);
        break;
    }
    return query.snapshots() as Stream<QuerySnapshot<Map<String, dynamic>>>;
  }

  Future<void> _updateMemo(Memo memo) async {
    if (memo.id == null) return;

    final dataToUpdate = {
      'title': memo.title,
      'content': memo.content,
      'timestamp': FieldValue.serverTimestamp(),
      'createdAt': memo.createdAt,
    };

    if (memo.createdAt == null) {
      dataToUpdate['createdAt'] = memo.timestamp ?? FieldValue.serverTimestamp();
    }

    await db.collection('memos').doc(memo.id).update(dataToUpdate);
  }

  Future<void> _deleteMemo(String? memoId) async {
    if (memoId == null) return;
    await db.collection('memos').doc(memoId).delete();
  }

  void _navigateToEditMemoPage(BuildContext context, Memo memo) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditMemoPage(
          memo: memo.copy(),
          onSave: (updatedMemo) {
            _updateMemo(updatedMemo);
          },
          onDelete: () {
            _deleteMemo(memo.id);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('메모장'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          PopupMenuButton<SortOrder>(
            icon: const Icon(Icons.sort, color: Colors.white),
            onSelected: (SortOrder result) {
              setState(() {
                _sortOrder = result;
              });
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<SortOrder>>[
              const PopupMenuItem<SortOrder>(
                value: SortOrder.recent,
                child: Text('최근 저장 순'),
              ),
              const PopupMenuItem<SortOrder>(
                value: SortOrder.old,
                child: Text('오래된 순'),
              ),
              const PopupMenuItem<SortOrder>(
                value: SortOrder.titleAZ,
                child: Text('제목 순 (가나다)'),
              ),
            ],
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: getMemosStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('데이터 오류: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('메모가 없습니다.'));
          }

          final memos = snapshot.data!.docs
              .map((doc) => Memo.fromFirestore(doc))
              .toList();

          return GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 0.85,
            ),
            padding: const EdgeInsets.all(10),
            itemCount: memos.length,
            itemBuilder: (context, index) {
              final memo = memos[index];

              return Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                child: InkWell(
                  onTap: () => _navigateToEditMemoPage(context, memo),
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          memo.title.isEmpty ? '제목이 없습니다' : memo.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: Text(
                            memo.content,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.black87,
                            ),
                            maxLines: 8,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          memo.timestamp?.toDate().toString().substring(0, 10) ?? '날짜 없음',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddMemoPage()),
          );
        },
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }
}