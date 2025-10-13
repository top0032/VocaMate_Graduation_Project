// lib/models/word_model.dart

class WordModel {
  final String id;
  final String themeId;
  final String word;
  final String meaning;
  final String level;

  WordModel({
    required this.id,
    required this.themeId,
    required this.word,
    required this.meaning,
    required this.level,
  });

  // Firestore 문서 데이터를 Dart 객체로 변환하는 팩토리
  factory WordModel.fromMap(Map<String, dynamic> map, String id) {
    return WordModel(
      id: id,
      // 💡 Firestore에 저장된 필드명과 정확히 일치해야 합니다. (themeId)
      themeId: map['themeId'] ?? '',
      word: map['word'] ?? '',
      meaning: map['meaning'] ?? '',
      level: map['level'] ?? '초급',
    );
  }
}
