// lib/services/theme_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/theme_model.dart';
import '../models/word_model.dart';

class ThemeService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // 1. Firestore에서 모든 테마 목록을 가져오는 함수
  Future<List<ThemeModel>> getThemes() async {
    try {
      final snapshot = await _db.collection('themes').get();
      return snapshot.docs
          .map((doc) => ThemeModel.fromMap(doc.data(), doc.id))
          .toList();
    } catch (e) {
      print("Error fetching themes: $e");
      return [];
    }
  }

  // 2. 특정 themeId에 해당하는 단어 목록을 가져오는 함수 (쿼리 디버깅 강화)
  Future<List<WordModel>> getWordsByTheme(String themeId) async {
    try {
      // 💡 쿼리 실행
      final snapshot = await _db
          .collection('words')
          .where('themeId', isEqualTo: themeId) // 쿼리 조건 확인
          .get();

      // 💡 단어가 없는지 확인 (0개면 빈 리스트 반환)
      if (snapshot.docs.isEmpty) {
        print("INFO: No words found for themeId: $themeId");
        return [];
      }

      // 💡 단어가 있다면 변환 후 리스트 반환
      return snapshot.docs
          .map((doc) => WordModel.fromMap(doc.data(), doc.id))
          .toList();
    } catch (e) {
      // 🚨 에러 발생 시 Firebase 인덱스 오류인지 확인
      print("🚨 FATAL ERROR fetching words by theme: $e");
      // Firestore 인덱스 오류 메시지가 콘솔에 출력되었는지 확인하세요!
      return [];
    }
  }
}
