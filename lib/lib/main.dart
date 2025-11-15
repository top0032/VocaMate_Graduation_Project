import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart'; // 💡 1. dotenv 패키지 import

// 💡 2. main 함수를 'async'로 변경해야 합니다.
Future<void> main() async {
  // 💡 3. runApp 전에 await를 사용하기 위해 Flutter 바인딩을 보장합니다.
  WidgetsFlutterBinding.ensureInitialized();

  // 💡 4. .env 파일을 메모리로 로드합니다.
  await dotenv.load(fileName: ".env");

  // 5. .env 파일이 로드된 후 앱을 실행합니다.
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: Scaffold(body: Center(child: Text('Hello World!'))),
    );
  }
}
