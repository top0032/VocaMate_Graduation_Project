// lib/services/theme_service.dart

import 'dart:convert';
import 'dart:typed_data'; // Uint8List를 사용하기 위해 추가
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:csv/csv.dart';
import '../models/theme_model.dart';
import '../models/word_model.dart';

class ThemeService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ... (getThemes and getWordsByTheme methods remain the same) ...
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

  Future<List<WordModel>> getWordsByTheme(String themeId) async {
    try {
      final snapshot = await _db
          .collection('words')
          .where('themeId', isEqualTo: themeId)
          .get();

      if (snapshot.docs.isEmpty) {
        print("INFO: No words found for themeId: $themeId");
        return [];
      }

      return snapshot.docs
          .map((doc) => WordModel.fromMap(doc.data(), doc.id))
          .toList();
    } catch (e) {
      print("🚨 FATAL ERROR fetching words by theme: $e");
      return [];
    }
  }


  // 3. CSV 데이터로부터 단어를 가져와 Firestore에 추가하는 함수
  Future<int> importWordsFromCsv(Uint8List fileBytes, String themeId) async {
    try {
      final csvString = utf8.decode(fileBytes);
      final fields = const CsvToListConverter().convert(csvString);

      final batch = _db.batch();
      int importedCount = 0;

      for (var i = 1; i < fields.length; i++) { // 헤더 행 건너뛰기
        final field = fields[i];
        if (field.length >= 3) {
          final word = field[0].toString().trim();
          final meaning = field[1].toString().trim();
          final level = field[2].toString().trim(); // CSV 레벨은 문자열로 가정

          if (word.isNotEmpty && meaning.isNotEmpty) {
            final wordRef = _db.collection('words').doc();
            batch.set(wordRef, {
              'themeId': themeId,
              'word': word,
              'meaning': meaning,
              'level': level,
              'tags': [], // CSV에는 태그 정보가 없으므로 빈 리스트
              'createdAt': FieldValue.serverTimestamp(),
            });
            importedCount++;
          }
        }
      }

      await batch.commit();
      return importedCount;
    } catch (e) {
      print("Error importing words from CSV: $e");
      rethrow;
    }
  }

  // 4. JSON 데이터로부터 단어를 가져와 Firestore에 추가하는 함수
  Future<int> importWordsFromJson(Uint8List fileBytes, String themeId) async {
    try {
      final jsonString = utf8.decode(fileBytes);
      final List<dynamic> wordsJson = jsonDecode(jsonString);

      final batch = _db.batch();
      int importedCount = 0;

      for (final wordData in wordsJson) {
        final word = wordData['word']?.toString().trim();
        final meaning = wordData['meaning']?.toString().trim();
        final level = wordData['level']?.toString().trim() ?? '초급';
        final tags = List<String>.from(wordData['tags'] ?? []);

        if (word != null && meaning != null && word.isNotEmpty && meaning.isNotEmpty) {
          final wordRef = _db.collection('words').doc();
          batch.set(wordRef, {
            'themeId': themeId,
            'word': word,
            'meaning': meaning,
            'level': level,
            'tags': tags,
            'createdAt': FieldValue.serverTimestamp(),
          });
          importedCount++;
        }
      }

      await batch.commit();
      return importedCount;
    } catch (e) {
      print("Error importing words from JSON: $e");
      rethrow;
    }
  }
}
