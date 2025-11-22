import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart'; // kDebugMode 사용

import '../models/theme_model.dart';
import '../models/word_model.dart';
import '../services/theme_service.dart';
import '../theme.dart';

class LearningScreen extends StatefulWidget {
  final ThemeModel theme;

  const LearningScreen({super.key, required this.theme});

  @override
  State<LearningScreen> createState() => _LearningScreenState();
}

class _LearningScreenState extends State<LearningScreen> {
  final ThemeService _themeService = ThemeService();
  final FlutterTts _flutterTts = FlutterTts();

  List<WordModel> _words = [];
  bool _isLoading = true;
  int _currentIndex = 0;
  bool _isFlipped = false;

  @override
  void initState() {
    super.initState();
    _initializeTts();
    _loadWords();
  }

  // TTS 초기화 (영어 전용 설정)
  Future<void> _initializeTts() async {
    try {
      await _flutterTts.setLanguage("en-US");
      await _flutterTts.setSpeechRate(0.7);
      await _flutterTts.setPitch(1.0);
    } catch (e) {
      if (kDebugMode) {
        print("Error initializing TTS: $e");
      }
    }
  }

  Future<void> _speak(String text) async {
    await _flutterTts.speak(text);
  }

  @override
  void dispose() {
    _flutterTts.stop();
    super.dispose();
  }

  Future<void> _loadWords() async {
    try {
      final words = await _themeService.getWordsByTheme(widget.theme.themeId);
      if (mounted) {
        setState(() {
          _words = words;
          // 단어를 알파벳순으로 정렬
          _words.sort((a, b) => a.word.compareTo(b.word));
          _isLoading = false;
        });
        if (_words.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('단어 로드 성공: 이 테마에 등록된 단어가 없습니다.')),
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

  // Gemini API 호출 (Firebase Functions 경유)
  void _showGeminiExample() async {
    if (_words.isEmpty || _isLoading) return;
    final currentWord = _words[_currentIndex];

    setState(() {
      _isLoading = true;
    });

    try {
      int retryCount = 0;
      const int maxRetries = 3;
      const Duration initialDelay = Duration(seconds: 2);

      // 💡 API URL 설정 (환경에 따라 자동 변경)
      // 배포 후에는 아래 주소를 실제 Firebase Functions URL로 변경해야 합니다.
      String getApiUrl() {
        // 1. 로컬 에뮬레이터 테스트 시 (Android)
        if (kDebugMode && defaultTargetPlatform == TargetPlatform.android) {
          return 'http://10.0.2.2:5001/voca-33a1c/us-central1/generateExample';
        }

        // 2. 로컬 에뮬레이터 테스트 시 (iOS/Web) 또는 실제 배포 URL
        // 실제 배포 시에는 'http://localhost...' 대신 Firebase URL을 넣으세요.
        // 예: return 'https://us-central1-voca-33a1c.cloudfunctions.net/api/generateExample'; // 💡 /api/ 추가
        return 'https://us-central1-voca-33a1c.cloudfunctions.net/api/generateExample';
      }

      final String finalUrl = getApiUrl();

      while (retryCount < maxRetries) {
        final response = await http.post(
          Uri.parse(finalUrl),
          headers: <String, String>{
            'Content-Type': 'application/json; charset=UTF-8',
          },
          body: jsonEncode(<String, String>{
            'word': currentWord.word,
            'meaning': currentWord.meaning,
            'level': currentWord.level,
            'theme': widget.theme.name,
          }),
        );

        if (response.statusCode == 200) {
          // 💡 한글 깨짐 방지를 위해 utf8.decode 사용
          final Map<String, dynamic> data = jsonDecode(
            utf8.decode(response.bodyBytes),
          );

          // Firebase Functions 응답 구조 확인 (result 객체 안에 있는지 확인)
          final resultData = data['result'] ?? data;
          final example = resultData['example'];
          final korean = resultData['korean'];

          final displayText = (example != null && korean != null)
              ? "예문: $example\n\n해석: $korean"
              : "예문을 생성할 수 없습니다.";

          if (mounted) {
            setState(() {
              _isLoading = false;
            });
            _showGeminiResultDialog(displayText);
          }
          return; // 성공 시 루프 종료
        } else if (response.statusCode == 503) {
          // 503 과부하 에러 시 재시도
          retryCount++;
          print('Gemini API 호출 실패 (503 과부하): 재시도 ${retryCount}/${maxRetries}');
          if (retryCount < maxRetries) {
            await Future.delayed(initialDelay * retryCount);
          } else {
            if (mounted) {
              setState(() {
                _isLoading = false;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Gemini 서비스가 혼잡합니다. 잠시 후 다시 시도해주세요.'),
                ),
              );
            }
            return;
          }
        } else {
          // 기타 서버 에러
          final Map<String, dynamic> errorData = jsonDecode(
            utf8.decode(response.bodyBytes),
          );
          final errorMessage = errorData['error'] ?? 'Unknown error';
          if (mounted) {
            setState(() {
              _isLoading = false;
            });
            print('Gemini API 호출 실패: ${response.statusCode} - $errorMessage');
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('서버 오류 발생: $errorMessage')));
          }
          return;
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        print('Gemini API 호출 실패 (Network): $e');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('서버 연결에 실패했습니다. 인터넷 연결을 확인해주세요.')),
        );
      }
    }
  }

  void _showGeminiResultDialog(String text) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Gemini 심화 학습 예문', style: TextStyle(fontSize: 18)),
              IconButton(
                icon: const Icon(Icons.volume_up),
                // 예문 중 영어 부분만 읽어주기 (간단한 파싱 또는 전체 읽기)
                onPressed: () => _speak(text),
              ),
            ],
          ),
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
    if (_isLoading && _words.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text('${widget.theme.name} 학습')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final currentWord = _words.isEmpty ? null : _words[_currentIndex];

    return Scaffold(
      appBar: AppBar(title: Text('${widget.theme.name} 학습')),
      body: Stack(
        children: [
          Center(
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
                          transitionBuilder:
                              (Widget child, Animation<double> animation) {
                                final rotateAnim = Tween(
                                  begin: 3.14,
                                  end: 0.0,
                                ).animate(animation);
                                return AnimatedBuilder(
                                  animation: rotateAnim,
                                  child: child,
                                  builder: (context, child) {
                                    final isUnder =
                                        (ValueKey(_isFlipped) != child!.key);
                                    var tilt =
                                        ((animation.value - 0.5).abs() - 0.5) *
                                        0.003;
                                    tilt *= isUnder ? -1.0 : 1.0;
                                    final value = isUnder
                                        ? rotateAnim.value < (3.14 / 2)
                                              ? rotateAnim.value
                                              : 3.14 - rotateAnim.value
                                        : rotateAnim.value;
                                    return Transform(
                                      transform: Matrix4.rotationY(value)
                                        ..setEntry(3, 0, tilt),
                                      alignment: Alignment.center,
                                      child: child,
                                    );
                                  },
                                );
                              },
                          child: _isFlipped
                              ? FlashCard(
                                  key: const ValueKey(true),
                                  word: currentWord!,
                                  isFront: false,
                                )
                              : FlashCard(
                                  key: const ValueKey(false),
                                  text: currentWord!.word,
                                  isFront: true,
                                  onSpeak: () => _speak(currentWord.word),
                                ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      Text(
                        '난이도: ${currentWord?.level ?? 'N/A'}',
                        style: AppTheme.themeData.textTheme.titleLarge,
                      ),
                      const SizedBox(height: 32),
                      ElevatedButton.icon(
                        onPressed: _isLoading ? null : _showGeminiExample,
                        icon: const Icon(Icons.lightbulb_outline),
                        label: const Text('심화 학습 (Gemini 예문 생성)'),
                      ),
                      const SizedBox(height: 32),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          ElevatedButton(
                            onPressed: _previousWord,
                            child: const Text('이전'),
                          ),
                          ElevatedButton(
                            onPressed: _nextWord,
                            child: const Text('다음'),
                          ),
                        ],
                      ),
                    ],
                  ),
          ),
          if (_isLoading && _words.isNotEmpty)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}

class FlashCard extends StatelessWidget {
  final String? text;
  final WordModel? word;
  final bool isFront;
  final VoidCallback? onSpeak;

  const FlashCard({
    super.key,
    this.text,
    this.word,
    required this.isFront,
    this.onSpeak,
  }) : assert(isFront ? text != null && onSpeak != null : word != null);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 10,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.8,
        height: 300,
        alignment: Alignment.center,
        padding: const EdgeInsets.all(16.0),
        child: isFront
            ? Stack(
                children: [
                  Center(
                    child: Text(
                      text!,
                      textAlign: TextAlign.center,
                      style: AppTheme.themeData.textTheme.displayMedium,
                    ),
                  ),
                  Positioned(
                    top: 10,
                    right: 10,
                    child: IconButton(
                      icon: const Icon(Icons.volume_up, size: 30),
                      onPressed: onSpeak,
                    ),
                  ),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    word!.meaning,
                    textAlign: TextAlign.center,
                    style: AppTheme.themeData.textTheme.displaySmall,
                  ),
                  const SizedBox(height: 16),
                  if (word!.partOfSpeech.isNotEmpty)
                    Text(
                      '[${word!.partOfSpeech}]',
                      style: AppTheme.themeData.textTheme.titleLarge?.copyWith(
                        fontStyle: FontStyle.italic,
                        color: Colors.grey[600],
                      ),
                    ),
                  const SizedBox(height: 16),
                  if (word!.phoneticUS.isNotEmpty)
                    Text(
                      '미국: ${word!.phoneticUS}',
                      style: AppTheme.themeData.textTheme.titleMedium,
                    ),
                  if (word!.phoneticUK.isNotEmpty)
                    Text(
                      '영국: ${word!.phoneticUK}',
                      style: AppTheme.themeData.textTheme.titleMedium,
                    ),
                ],
              ),
      ),
    );
  }
}
