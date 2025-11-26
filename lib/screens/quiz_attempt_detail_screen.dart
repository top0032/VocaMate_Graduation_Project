import 'package:flutter/material.dart';
import '../theme.dart';

class QuizAttemptDetailScreen extends StatelessWidget {
  final String quizTitle;
  final List<dynamic> results;

  const QuizAttemptDetailScreen({
    super.key,
    required this.quizTitle,
    required this.results,
  });

  @override
  Widget build(BuildContext context) {
    final int score = results.where((r) => r['wasCorrect'] == true).length;
    final int totalQuestions = results.length;

    return Scaffold(
      appBar: AppBar(
        title: Text(quizTitle),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              '총 $totalQuestions문제 중 $score개 정답!',
              style: AppTheme.themeData.textTheme.headlineMedium,
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: results.length,
              itemBuilder: (context, index) {
                final result = results[index] as Map<String, dynamic>;
                final bool wasCorrect = result['wasCorrect'] ?? false;

                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  color: wasCorrect ? Colors.green.shade50 : Colors.red.shade50,
                  child: ListTile(
                    leading: Icon(
                      wasCorrect ? Icons.check_circle : Icons.cancel,
                      color: wasCorrect ? Colors.green : Colors.red,
                    ),
                    title: Text(
                      result['word'] ?? '단어 정보 없음',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('정답: ${result['correctAnswer'] ?? ''}'),
                        if (!wasCorrect)
                          Text(
                            '선택한 답: ${result['selectedAnswer'] ?? ''}',
                            style: const TextStyle(color: Colors.red),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
