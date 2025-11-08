// lib/models/word_model.dart

class WordModel {
  final String id;
  final String themeId;
  final String word;
  final String meaning;
  final String level;
  final List<String> tags; // 💡 tags 필드 추가

  WordModel({
    required this.id,
    required this.themeId,
    required this.word,
    required this.meaning,
    required this.level,
    this.tags = const [], // 💡 기본값으로 빈 리스트 설정
  });

  // Firestore 문서 데이터를 Dart 객체로 변환하는 팩토리
  factory WordModel.fromMap(Map<String, dynamic> map, String id) {
    return WordModel(
      id: id,
      themeId: map['themeId'] ?? '',
      word: map['word'] ?? '',
      meaning: map['meaning'] ?? '',
      level: map['level']?.toString() ?? '초급', // 💡 level을 문자열로 변환
      // 💡 Firestore의 'tags' 필드(리스트)를 Dart의 List<String>으로 변환
      tags: List<String>.from(map['tags'] ?? []),
    );
  }
}
