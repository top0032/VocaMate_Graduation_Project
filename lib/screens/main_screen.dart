import 'package:flutter/material.dart';

class MainScreen extends StatelessWidget {
  const MainScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(60),
        child: Center(child: Text('VocaMate 메인 학습 화면', style: TextStyle(fontSize: 20))),
      ),
      body: Center(child: Text('로그인 성공! 이제 단어 학습을 시작합니다.')),
    );
  }
}