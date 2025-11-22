import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:audioplayers/audioplayers.dart';

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
  final AudioPlayer _audioPlayer = AudioPlayer();

  List<WordModel> _words = [];
  bool _isLoading = true;
  int _currentIndex = 0;
  bool _isFlipped = false;

  @override
  void initState() {
    super.initState();
    _loadWords();
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  // TTS 실행 함수 (속도 조절 가능)
  Future<void> _speak(String text, {double speed = 1.0}) async {
    if (text.isEmpty) return;

    // 💡 재생 전 기존 오디오 정지 (겹침 방지)
    await _audioPlayer.stop();

    try {
      // API URL 설정
      String getTtsApiUrl() {
        if (kDebugMode && defaultTargetPlatform == TargetPlatform.android) {
          // 로컬 에뮬레이터용 (필요시 사용)
          return 'http://10.0.2.2:5001/voca-33a1c/us-central1/api/generate-speech';
        }
        // 💡 실제 배포된 URL (반드시 본인의 배포된 주소인지 확인!)
        return 'https://us-central1-voca-33a1c.cloudfunctions.net/api/generate-speech';
      }

      final response = await http.post(
        Uri.parse(getTtsApiUrl()),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'text': text, 'speed': speed}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        String base64Audio = data['audioContent'];

        if (base64Audio.isNotEmpty) {
          final bytes = base64Decode(base64Audio);
          await _audioPlayer.play(BytesSource(bytes));
        }
      } else {
        if (kDebugMode) print('TTS Error: ${response.body}');
      }
    } catch (e) {
      if (kDebugMode) print('TTS Network Error: $e');
    }
  }

  Future<void> _loadWords() async {
    try {
      final words = await _themeService.getWordsByTheme(widget.theme.themeId);
      if (mounted) {
        setState(() {
          _words = words;
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

  // Gemini API 호출
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

      String getApiUrl() {
        if (kDebugMode && defaultTargetPlatform == TargetPlatform.android) {
          return 'http://10.0.2.2:5001/voca-33a1c/us-central1/api/generate-example';
        }
        return 'https://us-central1-voca-33a1c.cloudfunctions.net/api/generate-example';
      }

      final String finalUrl = getApiUrl();

      while (retryCount < maxRetries) {
        final response = await http.post(
          Uri.parse(finalUrl),
          headers: {'Content-Type': 'application/json; charset=UTF-8'},
          body: jsonEncode({
            'word': currentWord.word,
            'meaning': currentWord.meaning,
          }),
        );

        if (response.statusCode == 200) {
          final Map<String, dynamic> data = jsonDecode(
            utf8.decode(response.bodyBytes),
          );
          final generatedText = data['generatedText'];

          if (mounted) {
            setState(() => _isLoading = false);
            if (generatedText != null) {
              _showGeminiResultDialog(generatedText);
            } else {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('예문 생성 실패: 내용 없음')));
            }
          }
          return;
        } else if (response.statusCode == 503) {
          retryCount++;
          if (retryCount < maxRetries) {
            await Future.delayed(initialDelay * retryCount);
          } else {
            if (mounted) {
              setState(() => _isLoading = false);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Gemini 서비스 과부하. 잠시 후 다시 시도해주세요.'),
                ),
              );
            }
            return;
          }
        } else {
          if (mounted) {
            setState(() => _isLoading = false);
            print('API Error: ${response.statusCode}');
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('API 오류: ${response.statusCode}')),
            );
          }
          return;
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        print('API Exception: $e');
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('API 연결 실패: $e')));
      }
    }
  }

  void _showGeminiResultDialog(String text) {
    showDialog(
      context: context,
      barrierDismissible: false, // 바깥 클릭으로 닫기 방지 (실수 방지)
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Gemini 심화 예문', style: TextStyle(fontSize: 18)),
              IconButton(
                icon: const Icon(Icons.volume_up, color: Colors.teal),
                // 💡 예문 읽기 (속도 1.0)
                // 한글이 포함되어 있으므로 서버에서 자동으로 한국어 TTS로 읽어줍니다.
                onPressed: () => _speak(text, speed: 1.0),
              ),
            ],
          ),
          content: SingleChildScrollView(child: Text(text)),
          actions: <Widget>[
            TextButton(
              child: const Text('닫기'),
              onPressed: () async {
                // 💡 닫기 버튼을 누르면 오디오를 즉시 정지합니다.
                await _audioPlayer.stop();
                if (context.mounted) Navigator.of(context).pop();
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
                    '등록된 단어가 없습니다.',
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
                                  text: currentWord!.meaning,
                                  isFront: false,
                                  // 💡 한글 뜻 읽기 (서버가 한국어로 자동 처리)
                                  onSpeak: () => _speak(currentWord.meaning),
                                )
                              : FlashCard(
                                  key: const ValueKey(false),
                                  text: currentWord!.word,
                                  isFront: true,
                                  // 💡 영어 단어 읽기 (서버가 영어로 자동 처리)
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
  final String text;
  final bool isFront;
  final VoidCallback onSpeak;

  const FlashCard({
    super.key,
    required this.text,
    required this.isFront,
    required this.onSpeak,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 10,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.8,
        height: 300,
        alignment: Alignment.center,
        child: Stack(
          children: [
            Center(
              child: Text(
                text,
                textAlign: TextAlign.center,
                style: isFront
                    ? AppTheme.themeData.textTheme.displayMedium
                    : AppTheme.themeData.textTheme.displaySmall,
              ),
            ),
            if (isFront)
              Positioned(
                top: 10,
                right: 10,
                child: IconButton(
                  icon: const Icon(Icons.volume_up, size: 30),
                  onPressed: onSpeak,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
