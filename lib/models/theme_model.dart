// lib/models/theme_model.dart

class ThemeModel {
  final String themeId;
  final String name;

  ThemeModel({required this.themeId, required this.name});

  // Firestore 문서 데이터를 Dart 객체로 변환하는 팩토리
  factory ThemeModel.fromMap(Map<String, dynamic> map, String id) {
    return ThemeModel(themeId: id, name: map['name'] ?? '알 수 없는 테마');
  }
}
