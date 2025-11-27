import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../theme.dart';
import 'quiz_attempt_detail_screen.dart';

class QuizStatsScreen extends StatelessWidget {
  const QuizStatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('퀴즈 통계')),
        body: const Center(child: Text('통계를 보려면 로그인이 필요합니다.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('퀴즈 통계'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('quiz_attempts')
            .where('userId', isEqualTo: user.uid)
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('오류가 발생했습니다: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                '아직 푼 퀴즈가 없습니다.',
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
            );
          }

          final attempts = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: attempts.length,
            itemBuilder: (context, index) {
              final attempt = attempts[index].data() as Map<String, dynamic>;
              final timestamp = attempt['timestamp'] as Timestamp?;
              final score = attempt['score'] ?? 0;
              final totalQuestions = attempt['totalQuestions'] ?? 0;
              final accuracy = totalQuestions > 0 ? (score / totalQuestions * 100).round() : 0;
              final quizTitle = attempt['quizTitle'] ?? '제목 없음';
              final results = attempt['results'] as List<dynamic>? ?? [];


              return Card(
                elevation: 3,
                margin: const EdgeInsets.only(bottom: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  title: Text(
                    quizTitle,
                    style: AppTheme.themeData.textTheme.headlineSmall,
                  ),
                  subtitle: Text(
                    timestamp != null
                        ? DateFormat('yyyy년 MM월 dd일 HH:mm').format(timestamp.toDate())
                        : '날짜 정보 없음',
                    style: const TextStyle(color: Colors.grey),
                  ),
                  trailing: Text(
                    '$score / $totalQuestions\n($accuracy%)',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: accuracy > 80 ? Colors.green : (accuracy > 50 ? Colors.orange : Colors.red),
                    ),
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => QuizAttemptDetailScreen(
                          quizTitle: quizTitle,
                          results: results,
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}

