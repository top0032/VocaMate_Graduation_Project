
import 'package:flutter/material.dart';
import '../models/theme_model.dart';
import '../models/word_model.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../services/theme_service.dart';
import '../theme.dart';

const String _apiKey =
    'AIzaSyBIMwEgY7epbEQ8wree_mN-rjz09TCc2-g'; // TODO: Replace with your actual API key

class LearningScreen extends StatefulWidget {
  final ThemeModel theme; // 선택된 테마 정보를 받음

  const LearningScreen({super.key, required this.theme});

  @override
  State<LearningScreen> createState() => _LearningScreenState();
}

class _LearningScreenState extends State<LearningScreen> {
  final ThemeService _themeService = ThemeService();
  List<WordModel> _words = [];
  bool _isLoading = true;
  int _currentIndex = 0; // 현재 보고 있는 단어의 인덱스
  bool _isFlipped = false;

  @override
  void initState() {
    super.initState();
    _loadWords();
  }

  Future<void> _loadWords() async {
    try {
      final words = await _themeService.getWordsByTheme(widget.theme.themeId);
      if (mounted) {
        setState(() {
          _words = words;
          _isLoading = false;
        });
        if (_words.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                '단어 로드 성공: 이 테마에 등록된 단어가 없습니다.',
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        print('단어 로드 실패: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('단어 로드 중 오류가 발생했습니다: ${e.toString()}')),
        );
      }
    }
  }

  void _showGeminiExample() async {
    if (_words.isEmpty) return;
    final currentWord = _words[_currentIndex];

    if (_apiKey.isEmpty ||
        _apiKey == 'AIzaSyBYnhM6ymkPOa3tlTRxK-kq7tKRViwRyXA') {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Gemini API 키를 설정해주세요.')));
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final model = GenerativeModel(model: 'gemini-pro', apiKey: _apiKey);
      final content = [
        Content.text(
          '''Generate 3 example sentences using the English word "${currentWord.word}" with its Korean meaning "${currentWord.meaning}". Provide the output in Korean. Each example sentence should be on a new line, followed by its Korean translation on the next line. For example:
English sentence 1.
한국어 번역 1.
English sentence 2.
한국어 번역 2.
English sentence 3.
한국어 번역 3.''',
        ),
      ];

      final response = await model.generateContent(content);
      final generatedText = response.text;

      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        if (generatedText != null) {
          _showGeminiResultDialog(generatedText);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Gemini로부터 예문을 생성하지 못했습니다.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        print('Gemini API 호출 실패: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gemini API 호출 중 오류가 발생했습니다: ${e.toString()}'),
          ),
        );
      }
    }
  }

  void _showGeminiResultDialog(String text) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Gemini 심화 학습 예문'),
          content: SingleChildScrollView(child: Text(text)),
          actions: <Widget>[
            TextButton(
              child: const Text('닫기'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _nextWord() {
    setState(() {
      _currentIndex = (_currentIndex + 1) % _words.length;
      _isFlipped = false;
    });
  }

  void _previousWord() {
    setState(() {
      _currentIndex = (_currentIndex - 1 + _words.length) % _words.length;
      _isFlipped = false;
    });
  }

  void _flipCard() {
    setState(() {
      _isFlipped = !_isFlipped;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final currentWord = _words.isEmpty ? null : _words[_currentIndex];

    return Scaffold(
      appBar: AppBar(title: Text('${widget.theme.name} 학습')),
      body: Center(
        child: _words.isEmpty
            ? const Text(
                '이 테마에 등록된 단어가 없습니다.',
                style: TextStyle(fontSize: 18, color: Colors.red),
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: _flipCard,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 500),
                      transitionBuilder: (Widget child, Animation<double> animation) {
                        final rotateAnim = Tween(begin: 3.14, end: 0.0).animate(animation);
                        return AnimatedBuilder(
                          animation: rotateAnim,
                          child: child,
                          builder: (context, child) {
                            final isUnder = (ValueKey(_isFlipped) != child!.key);
                            var tilt = ((animation.value - 0.5).abs() - 0.5) * 0.003;
                            tilt *= isUnder ? -1.0 : 1.0;
                            final value = isUnder ? rotateAnim.value < (3.14 / 2) ? rotateAnim.value : 3.14 - rotateAnim.value : rotateAnim.value;
                            return Transform(
                              transform: Matrix4.rotationY(value)..setEntry(3, 0, tilt),
                              child: child,
                              alignment: Alignment.center,
                            );
                          },
                        );
                      },
                      child: _isFlipped
                          ? FlashCard(key: const ValueKey(true), text: currentWord!.meaning, isFront: false)
                          : FlashCard(key: const ValueKey(false), text: currentWord!.word, isFront: true),
                    ),
                  ),
                  const SizedBox(height: 32),
                  Text('난이도: ${currentWord?.level}', style: AppTheme.themeData.textTheme.titleLarge),
                  const SizedBox(height: 32),
                  ElevatedButton.icon(
                    onPressed: _showGeminiExample,
                    icon: const Icon(Icons.lightbulb_outline),
                    label: const Text('심화 학습 (Gemini 예문 생성)'),
                  ),
                  const SizedBox(height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton(onPressed: _previousWord, child: const Text('이전')),
                      ElevatedButton(onPressed: _nextWord, child: const Text('다음')),
                    ],
                  ),
                ],
              ),
      ),
    );
  }
}

class FlashCard extends StatelessWidget {
  final String text;
  final bool isFront;

  const FlashCard({super.key, required this.text, required this.isFront});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 10,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.8,
        height: 300,
        alignment: Alignment.center,
        child: Text(
          text,
          style: isFront
              ? AppTheme.themeData.textTheme.displayMedium
              : AppTheme.themeData.textTheme.displaySmall,
        ),
      ),
    );
  }
}
