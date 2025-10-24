// lib/models/memo.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class Memo {
  String? id;
  String title;
  String content;
  Timestamp? timestamp; // updatedAt 역할
  Timestamp? createdAt;

  Memo({this.id, required this.title, required this.content, this.timestamp, this.createdAt});

  factory Memo.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return Memo(
      id: doc.id,
      title: data['title'] ?? '',
      content: data['content'] ?? '',
      timestamp: data['timestamp'] as Timestamp?,
      createdAt: data['createdAt'] as Timestamp?, // createdAt 필드 읽기
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'content': content,
      'timestamp': timestamp,
      'createdAt': createdAt,
    };
  }

  Memo copy() {
    return Memo(id: id, title: title, content: content, timestamp: timestamp, createdAt: createdAt);
  }
}