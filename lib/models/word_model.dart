// lib/models/word_model.dart

class WordModel {
  final String id;
  final String themeId;
  final String word;
  final String meaning;
  final String level;
  final List<String> tags;
  final String partOfSpeech; // 품사
  final String phoneticUK;   // 영국식 발음
  final String phoneticUS;   // 미국식 발음

  WordModel({
    required this.id,
    required this.themeId,
    required this.word,
    required this.meaning,
    required this.level,
    this.tags = const [],
    this.partOfSpeech = '',
    this.phoneticUK = '',
    this.phoneticUS = '',
  });

  // Firestore 문서 데이터를 Dart 객체로 변환하는 팩토리
  factory WordModel.fromMap(Map<String, dynamic> map, String id) {
    return WordModel(
      id: id,
      themeId: map['themeId'] ?? '',
      word: map['word'] ?? '',
      meaning: map['meaning'] ?? '',
      level: map['level']?.toString() ?? '초급',
      tags: List<String>.from(map['tags'] ?? []),
      partOfSpeech: map['partOfSpeech'] ?? '',
      phoneticUK: map['phoneticUK'] ?? '',
      phoneticUS: map['phoneticUS'] ?? '',
    );
  }
}
