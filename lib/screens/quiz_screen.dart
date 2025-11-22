import 'package:flutter/material.dart';

class QuizScreen extends StatelessWidget {
  const QuizScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('퀴즈'),
      ),
      body: const Center(
        child: Text('퀴즈 기능은 아직 준비 중입니다!'),
      ),
    );
  }
}
