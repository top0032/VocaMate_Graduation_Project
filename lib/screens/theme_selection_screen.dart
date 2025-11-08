import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../models/theme_model.dart';
import '../services/theme_service.dart';
import 'learning_screen.dart';
import '../theme.dart';

class ThemeSelectionScreen extends StatefulWidget {
  const ThemeSelectionScreen({super.key});

  @override
  State<ThemeSelectionScreen> createState() => _ThemeSelectionScreenState();
}

class _ThemeSelectionScreenState extends State<ThemeSelectionScreen> {
  final ThemeService _themeService = ThemeService();
  Future<List<ThemeModel>>? _themesFuture;

  @override
  void initState() {
    super.initState();
    _loadThemes();
  }

  void _loadThemes() {
    setState(() {
      _themesFuture = _themeService.getThemes();
    });
  }

  void _onThemeSelected(ThemeModel selectedTheme) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LearningScreen(theme: selectedTheme),
      ),
    );
  }

  Future<void> _importWords() async {
    // 1. 파일 선택 (CSV 또는 JSON)
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv', 'json'],
      withData: true, // 💡 웹에서 파일 내용을 읽기 위해 true로 설정
    );

    if (result == null || result.files.single.bytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('파일을 선택하지 않았거나 읽을 수 없습니다.')),
      );
      return;
    }

    final file = result.files.single;
    final fileBytes = file.bytes!;
    final fileExtension = file.extension?.toLowerCase();

    if (fileExtension != 'csv' && fileExtension != 'json') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('지원하지 않는 파일 형식입니다 (CSV 또는 JSON 선택).')),
      );
      return;
    }

    final themes = await _themesFuture;
    if (!mounted || themes == null || themes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('단어를 추가할 테마가 없습니다.')),
      );
      return;
    }

    // 2. 테마 선택 다이얼로그
    final selectedTheme = await showDialog<ThemeModel>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('가져올 테마 선택'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: themes.length,
            itemBuilder: (context, index) {
              return ListTile(
                title: Text(themes[index].name),
                onTap: () => Navigator.of(context).pop(themes[index]),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('취소'),
          ),
        ],
      ),
    );

    if (selectedTheme == null) return;

    // 3. 파일 종류에 따라 적절한 서비스 호출
    try {
      int importedCount = 0;
      if (fileExtension == 'csv') {
        importedCount = await _themeService.importWordsFromCsv(fileBytes, selectedTheme.themeId);
      } else if (fileExtension == 'json') {
        importedCount = await _themeService.importWordsFromJson(fileBytes, selectedTheme.themeId);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$importedCount개의 단어를 \'${selectedTheme.name}\' 테마에 추가했습니다.'),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('파일 가져오기 중 오류가 발생했습니다: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('테마 선택'),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_upload),
            onPressed: _importWords,
            tooltip: 'CSV/JSON 파일에서 단어 가져오기',
          ),
        ],
      ),
      body: FutureBuilder<List<ThemeModel>>(
        future: _themesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('테마 로드 오류: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('등록된 학습 테마가 없습니다.'));
          }

          final themes = snapshot.data!;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: themes.length,
            itemBuilder: (context, index) {
              final theme = themes[index];
              return Card(
                elevation: 2,
                margin: const EdgeInsets.symmetric(vertical: 8.0),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  title: Text(
                    theme.name,
                    style: AppTheme.themeData.textTheme.headlineSmall,
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: () => _onThemeSelected(theme),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
