import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../main_screen.dart'; // 로그인 후 이동할 메인 화면
import 'login_screen.dart'; // 초기 로그인 화면

class AuthCheckScreen extends StatelessWidget {
  const AuthCheckScreen({super.key});

  Widget _buildScreen(User? user) {
    if (user != null) {
      // 사용자 데이터가 있다면 메인 화면으로 이동
      return const MainScreen();
    } else {
      // 사용자 데이터가 없다면 로그인 화면으로 이동
      return const LoginScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    // 앱 시작 시 잔여 세션을 강제 로그아웃하여 항상 로그아웃 상태로 시작
    return FutureBuilder(
      future: FirebaseAuth.instance.signOut(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // 강제 로그아웃 후, 실제 인증 상태 변화를 감지하여 화면 분기
        return StreamBuilder<User?>(
          stream: FirebaseAuth.instance.authStateChanges(),
          builder: (context, streamSnapshot) {
            if (streamSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            return _buildScreen(streamSnapshot.data);
          },
        );
      },
    );
  }
}
