import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
  bool _isFavorite = false;

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

  // Cloud TTS 호출 및 재생
  Future<void> _speak(String text, {double speed = 1.0}) async {
    if (text.isEmpty) return;
    await _audioPlayer.stop();

    try {
      String getTtsApiUrl() {
        if (kDebugMode && defaultTargetPlatform == TargetPlatform.android) {
          return 'http://10.0.2.2:5001/voca-33a1c/us-central1/api/generate-speech';
        }
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
        if (_words.isNotEmpty) {
          _checkFavoriteStatus();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('단어 로드 성공: 이 테마에 등록된 단어가 없습니다.')),
          );
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      print('단어 로드 실패: $e');
    }
  }

  Future<void> _checkFavoriteStatus() async {
    if (_words.isEmpty) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final currentWord = _words[_currentIndex];

    final docRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('favorites')
        .doc(currentWord.word);

    try {
      final doc = await docRef.get();
      if (mounted) setState(() => _isFavorite = doc.exists);
    } catch (e) {
      print("즐겨찾기 확인 오류: $e");
    }
  }

  Future<void> _toggleFavorite() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('로그인이 필요합니다.')));
      return;
    }
    final currentWord = _words[_currentIndex];
    final docRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('favorites')
        .doc(currentWord.word);

    if (_isFavorite) {
      await docRef.delete();
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('삭제됨')));
    } else {
      // 기본 저장 시에도 모든 정보 저장
      await docRef.set({
        'word': currentWord.word,
        'meaning': currentWord.meaning,
        'level': currentWord.level,
        'theme': widget.theme.name,
        'partOfSpeech': currentWord.partOfSpeech ?? '',
        'phoneticUS': currentWord.phoneticUS ?? '',
        'phoneticUK': currentWord.phoneticUK ?? '',
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('저장됨')));
    }
    setState(() => _isFavorite = !_isFavorite);
  }

  // 💡 [핵심 수정] Gemini 예문 저장 함수
  Future<void> _saveGeminiResult(String resultText) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final currentWord = _words[_currentIndex];

    try {
      final docRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('favorites')
          .doc(currentWord.word);

      // 1. 문서가 이미 존재하는지 확인
      final docSnapshot = await docRef.get();

      // 2. 저장할 데이터 준비 (기본 단어 정보)
      final Map<String, dynamic> data = {
        'word': currentWord.word,
        'meaning': currentWord.meaning,
        'level': currentWord.level,
        'theme': widget.theme.name,
        'partOfSpeech': currentWord.partOfSpeech ?? '',
        'phoneticUS': currentWord.phoneticUS ?? '',
        'phoneticUK': currentWord.phoneticUK ?? '',

        // 예문 배열에 추가 (arrayUnion 사용)
        'ai_examples': FieldValue.arrayUnion([
          {'content': resultText, 'savedAt': Timestamp.now()},
        ]),
        'lastUpdatedAt': FieldValue.serverTimestamp(),
      };

      // 💡 3. 만약 문서가 처음 생성되는 것이라면 createdAt을 추가
      if (!docSnapshot.exists) {
        data['createdAt'] = FieldValue.serverTimestamp();
      }

      // 4. 데이터 저장 (merge: true로 기존 데이터 유지)
      await docRef.set(data, SetOptions(merge: true));

      if (mounted) {
        setState(() => _isFavorite = true); // 별표 채우기
        Navigator.pop(context); // 다이얼로그 닫기
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('예문이 단어장(즐겨찾기)에 저장되었습니다.')),
        );
      }
    } catch (e) {
      print('Save Error: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('저장 중 오류가 발생했습니다.')));
    }
  }

  void _showGeminiExample() async {
    if (_words.isEmpty || _isLoading) return;
    final currentWord = _words[_currentIndex];

    setState(() => _isLoading = true);

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
              ).showSnackBar(const SnackBar(content: Text('내용 없음')));
            }
          }
          return;
        } else if (response.statusCode == 503) {
          retryCount++;
          await Future.delayed(initialDelay * retryCount);
        } else {
          if (mounted) {
            setState(() => _isLoading = false);
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('연결 실패: $e')));
      }
    }
  }

  void _showGeminiResultDialog(String text) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Gemini 심화 예문', style: TextStyle(fontSize: 18)),
              IconButton(
                icon: const Icon(Icons.volume_up, color: Colors.teal),
                onPressed: () => _speak(text, speed: 1.0),
              ),
            ],
          ),
          content: SingleChildScrollView(child: Text(text)),
          actions: <Widget>[
            TextButton.icon(
              icon: const Icon(Icons.save_alt),
              label: const Text('저장 (나만의 단어장)'),
              onPressed: () => _saveGeminiResult(text),
            ),
            TextButton(
              child: const Text('닫기'),
              onPressed: () async {
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
      _checkFavoriteStatus();
    });
  }

  void _previousWord() {
    setState(() {
      _currentIndex = (_currentIndex - 1 + _words.length) % _words.length;
      _isFlipped = false;
      _checkFavoriteStatus();
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
      appBar: AppBar(
        title: Text('${widget.theme.name} 학습'),
        actions: [
          if (currentWord != null)
            IconButton(
              icon: Icon(
                _isFavorite ? Icons.star : Icons.star_border,
                color: _isFavorite ? Colors.yellow : Colors.white,
                size: 30,
              ),
              onPressed: _toggleFavorite,
            ),
        ],
      ),
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
