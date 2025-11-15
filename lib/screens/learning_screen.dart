// 💡 중복된 import문 정리 및 누락된 패키지 추가
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart'; // 💡 kDebugMode 사용을 위해 추가
import 'package:flutter_dotenv/flutter_dotenv.dart'; // 💡 1. dotenv 패키지 import

import '../models/theme_model.dart';
import '../models/word_model.dart';
import '../services/theme_service.dart';
import '../theme.dart'; // 💡 AppTheme 사용을 위해 import (이 파일이 존재해야 함)
// import 'package:google_generative_ai/google_generative_ai.dart'; // 💡 사용되지 않으므로 제거 (http 사용)

class LearningScreen extends StatefulWidget {
  final ThemeModel theme; // 선택된 테마 정보를 받음

  const LearningScreen({super.key, required this.theme});

  @override
  State<LearningScreen> createState() => _LearningScreenState();
}

class _LearningScreenState extends State<LearningScreen> {
  final ThemeService _themeService = ThemeService();
  final FlutterTts _flutterTts = FlutterTts(); // 💡 TTS 인스턴스 추가

  List<WordModel> _words = [];
  bool _isLoading = true; // 💡 단어 로드 및 Gemini 호출 시 사용할 로딩 변수
  int _currentIndex = 0; // 현재 보고 있는 단어의 인덱스
  bool _isFlipped = false;

  @override
  void initState() {
    super.initState();
    _initializeTts();
    _loadWords();
  }

  // 💡 TTS 초기화 및 영어 음성 설정
  Future<void> _initializeTts() async {
    try {
      // 사용 가능한 음성 목록 가져오기
      var voices = await _flutterTts.getVoices;
      // 한국어 음성 ('ko-KR') 찾기
      var koreanVoice = voices.firstWhere(
        (voice) => voice['locale'] == 'ko-KR',
        orElse: () => null,
      );

      // 한국어 음성이 있으면 설정, 없으면 기본 한국어 언어 사용
      if (koreanVoice != null) {
        // 💡 setVoice가 Map<String, String>을 기대하므로 타입을 변환해줍니다.
        final voiceMap = Map<String, String>.from(
          koreanVoice.cast<String, String>(),
        );
        await _flutterTts.setVoice(voiceMap);
        if (kDebugMode) {
          print("Selected TTS voice: $voiceMap");
        }
      } else {
        if (kDebugMode) {
          print("ko-KR voice not found, using default language.");
        }
        await _flutterTts.setLanguage("ko-KR");
      }
    } catch (e) {
      if (kDebugMode) {
        print("Error initializing TTS: $e");
      }
    }

    await _flutterTts.setSpeechRate(0.8);
    await _flutterTts.setPitch(1.0);
  }

  // 💡 텍스트를 읽어주는 함수
  Future<void> _speak(String text) async {
    await _flutterTts.speak(text);
  }

  @override
  void dispose() {
    _flutterTts.stop(); // 💡 화면이 dispose될 때 TTS 정지
    super.dispose();
  }

  Future<void> _loadWords() async {
    try {
      final words = await _themeService.getWordsByTheme(widget.theme.themeId);
      if (mounted) {
        setState(() {
          _words = words;
          // 💡 단어를 알파벳순으로 정렬
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

  // 💡 Gemini API 호출 (Firebase Functions 경유)
  void _showGeminiExample() async {
    if (_words.isEmpty || _isLoading) return; // 💡 로딩 중일 때 중복 호출 방지
    final currentWord = _words[_currentIndex];

    setState(() {
      _isLoading = true; // 💡 로딩 시작
    });

    try {
      int retryCount = 0;
      const int maxRetries = 3;
      const Duration initialDelay = Duration(seconds: 2);

      // 💡 2. .env 파일에서 Firebase URL 읽어오기
      final String? baseUrl = dotenv.env['API_BASE_URL'];

      // 💡 3. .env 파일에 URL이 설정되었는지 확인
      if (baseUrl == null || baseUrl.isEmpty) {
        if (kDebugMode) {
          print('오류: .env 파일에 API_BASE_URL이 설정되지 않았습니다.');
        }
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('.env 파일에 API URL이 설정되지 않았습니다.')),
          );
        }
        return; // 함수 종료
      }

      // 💡 4. 최종 URL 조합 (예: https://.../api/generate-example)
      final String finalUrl = '$baseUrl/generate-example';

      // 💡 5. getApiUrl() 함수 삭제 (더 이상 필요 없음)
      /*
      String getApiUrl() {
        if (kDebugMode && defaultTargetPlatform == TargetPlatform.android) {
          return 'http://10.0.2.2:3000/generate-example';
        }
        return 'http://localhost:3000/generate-example';
      }
      */

      while (retryCount < maxRetries) {
        final response = await http.post(
          // 💡 6. 하드코딩된 주소 대신 finalUrl 변수 사용
          Uri.parse(finalUrl),
          headers: <String, String>{
            'Content-Type': 'application/json; charset=UTF-8',
          },
          body: jsonEncode(<String, String>{
            'word': currentWord.word,
            'meaning': currentWord.meaning,
          }),
        );

        if (response.statusCode == 200) {
          final Map<String, dynamic> data = jsonDecode(
            utf8.decode(response.bodyBytes),
          ); // 💡 한글 깨짐 방지
          final generatedText = data['generatedText'];

          if (mounted) {
            // 💡 성공 시 로딩 종료
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
          return; // 성공, 반복 종료
        } else if (response.statusCode == 503) {
          // 과부하, 재시도
          retryCount++;
          print('Gemini API 호출 실패 (503 과부하): 재시도 ${retryCount}/${maxRetries}');
          if (retryCount < maxRetries) {
            await Future.delayed(initialDelay * retryCount);
          } else {
            // 최대 재시도 도달
            if (mounted) {
              setState(() {
                _isLoading = false;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Gemini 서비스가 과부하되었습니다. 잠시 후 다시 시도해주세요.'),
                ),
              );
            }
            return;
          }
        } else {
          // 그 외 서버 오류
          final Map<String, dynamic> errorData = jsonDecode(
            utf8.decode(response.bodyBytes),
          ); // 💡 한글 깨짐 방지
          final errorMessage = errorData['error'] ?? 'Unknown error';
          if (mounted) {
            setState(() {
              _isLoading = false;
            });
            print('Gemini API 호출 실패: ${response.statusCode} - $errorMessage');
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Gemini API 호출 중 오류가 발생했습니다: $errorMessage'),
              ),
            );
          }
          return; // 반복 종료
        }
      }
    } catch (e) {
      // 💡 네트워크 연결 실패 (Failed to fetch) 등
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        print('Gemini API 호출 실패 (Exception): $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gemini API 연결에 실패했습니다: ${e.toString()}')),
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
              const Text('Gemini 심화 학습 예문'),
              IconButton(
                icon: const Icon(Icons.volume_up),
                onPressed: () => _speak(text), // 💡 예문 읽어주기
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
    // 💡 _isLoading이 true일 때 로딩 인디케이터를 먼저 표시
    if (_isLoading && _words.isEmpty) {
      // 💡 단어 로딩 중에만 전체 화면 로딩
      return Scaffold(
        appBar: AppBar(title: Text('${widget.theme.name} 학습')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final currentWord = _words.isEmpty ? null : _words[_currentIndex];

    return Scaffold(
      appBar: AppBar(title: Text('${widget.theme.name} 학습')),
      body: Stack(
        // 💡 로딩 인디케이터를 위에 띄우기 위해 Stack 사용
        children: [
          Center(
            child: _words.isEmpty
                ? const Text(
                    '이 테마에 등록된 단어가 없습니다.',
                    style: TextStyle(fontSize: 18, color: Colors.red),
                  )
                // 💡 단어가 있을 때만 Column 표시
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
                                      child: child,
                                      alignment: Alignment.center,
                                    );
                                  },
                                );
                              },
                          // 💡 currentWord가 null이 아님을 보장 (위에서 _words.isEmpty로 체크)
                          child: _isFlipped
                              ? FlashCard(
                                  key: const ValueKey(true),
                                  text: currentWord!.meaning,
                                  isFront: false,
                                  onSpeak: () => _speak(currentWord.meaning),
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
                      // 💡 currentWord가 null일 경우 대비
                      Text(
                        '난이도: ${currentWord?.level ?? 'N/A'}',
                        style: AppTheme.themeData.textTheme.titleLarge,
                      ),
                      const SizedBox(height: 32),
                      ElevatedButton.icon(
                        // 💡 로딩 중일 때는 버튼 비활성화
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
          // 💡 Gemini API 호출 로딩 인디케이터
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
  final VoidCallback onSpeak; // 💡 TTS 함수를 받기 위한 콜백

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
                textAlign: TextAlign.center, // 💡 텍스트 중앙 정렬
                style: isFront
                    ? AppTheme.themeData.textTheme.displayMedium
                    : AppTheme.themeData.textTheme.displaySmall,
              ),
            ),
            // 💡 영어 단어일 때만 스피커 아이콘 표시
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
