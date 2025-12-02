import 'package:flutter/material.dart';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/theme_model.dart';
import '../models/word_model.dart';
import '../services/theme_service.dart';
import '../theme.dart';

// 각 퀴즈 문제의 결과를 저장하기 위한 모델
class QuizResult {
  final WordModel questionWord;
  final String selectedAnswer;
  final String correctAnswer;
  final bool wasCorrect;

  QuizResult({
    required this.questionWord,
    required this.selectedAnswer,
    required this.correctAnswer,
    required this.wasCorrect,
  });

  // Firestore 저장을 위한 Map 변환
  Map<String, dynamic> toMap() {
    return {
      'word': questionWord.word,
      'meaning': questionWord.meaning,
      'level': questionWord.level,
      'selectedAnswer': selectedAnswer,
      'correctAnswer': correctAnswer,
      'wasCorrect': wasCorrect,
    };
  }
}

class QuizPage extends StatefulWidget {
  final ThemeModel? theme;
  final List<WordModel>? words;
  final int numberOfQuestions;
  final String quizTitle;

  const QuizPage({
    super.key,
    this.theme,
    this.words,
    required this.numberOfQuestions,
    required this.quizTitle,
  }) : assert(theme != null || words != null, 'Either theme or words must be provided.');

  @override
  State<QuizPage> createState() => _QuizPageState();
}

class _QuizPageState extends State<QuizPage> {
  final ThemeService _themeService = ThemeService();
  List<WordModel> _allWords = [];
  List<WordModel> _quizWords = [];
  bool _isLoading = true;
  int _currentIndex = 0;
  List<String> _options = [];
  String? _correctAnswerMeaning;
  String? _selectedAnswer;
  final List<QuizResult> _results = [];
  bool _quizCompleted = false;
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _loadWords();
  }

  Future<void> _loadWords() async {
    try {
      List<WordModel> fetchedWords;
      if (widget.words != null) {
        // '나만의 단어장' 같이 단어 목록이 직접 제공된 경우
        fetchedWords = widget.words!;
      } else {
        // 기존처럼 테마 ID로 단어를 가져오는 경우
        fetchedWords = await _themeService.getWordsByTheme(widget.theme!.themeId);
      }
      
      if (mounted) {
        setState(() {
          _allWords = fetchedWords;
          _prepareQuizWords();
          _isLoading = false;
          if (_quizWords.isNotEmpty) {
            _generateQuestion();
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('단어 로딩 중 오류가 발생했습니다: $e')),
        );
      }
    }
  }

  void _prepareQuizWords() {
    _allWords.shuffle(_random);
    if (widget.numberOfQuestions > 0 && widget.numberOfQuestions < _allWords.length) {
      _quizWords = _allWords.take(widget.numberOfQuestions).toList();
    } else {
      _quizWords = List.from(_allWords); // 원본 리스트 수정을 방지하기 위해 복사
    }
  }

  void _generateQuestion() {
    if (_quizWords.isEmpty) return;

    final currentWord = _quizWords[_currentIndex];
    _correctAnswerMeaning = currentWord.meaning;
    
    // 전체 단어 목록에서 오답 선택지를 생성 (테마 단어 + 나만의 단어장 단어 모두 포함 가능)
    List<String> incorrectMeanings = [];
    List<WordModel> otherWords = _allWords.where((word) => word.word != currentWord.word).toList();
    otherWords.shuffle(_random);

    for (int i = 0; i < 3 && i < otherWords.length; i++) {
      incorrectMeanings.add(otherWords[i].meaning);
    }

    _options = [_correctAnswerMeaning!, ...incorrectMeanings];
    _options.shuffle(_random);

    _selectedAnswer = null;
  }
  
  void _selectAnswer(String selectedMeaning) {
    setState(() {
      _selectedAnswer = selectedMeaning;
    });
  }

  void _nextQuestion() {
    if (_selectedAnswer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('답변을 선택해주세요!')),
      );
      return;
    }

    final currentWord = _quizWords[_currentIndex];
    final bool wasCorrect = _selectedAnswer == _correctAnswerMeaning;
    _results.add(QuizResult(
      questionWord: currentWord,
      selectedAnswer: _selectedAnswer!,
      correctAnswer: _correctAnswerMeaning!,
      wasCorrect: wasCorrect,
    ));

    if (_currentIndex >= _quizWords.length - 1) {
      // 퀴즈가 끝나면 결과 저장
      _saveQuizAttempt();
      setState(() {
        _quizCompleted = true;
      });
    } else {
      setState(() {
        _currentIndex++;
        _generateQuestion();
      });
    }
  }

  void _restartQuiz() {
    setState(() {
      _isLoading = false;
      _currentIndex = 0;
      _results.clear();
      _quizCompleted = false;
      _prepareQuizWords();
      if (_quizWords.isNotEmpty) {
        _generateQuestion();
      }
    });
  }

  Future<void> _exitQuiz() async {
    final bool? shouldExit = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('퀴즈 중단'),
        content: const Text('퀴즈를 중단하고 결과 화면으로 이동하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('나가기'),
          ),
        ],
      ),
    );

    if (shouldExit == true) {
      // 퀴즈 결과가 있을 때만 저장
      if (_results.isNotEmpty) {
        _saveQuizAttempt();
      }
      setState(() {
        _quizCompleted = true;
      });
    }
  }

  // 퀴즈 결과를 Firestore에 저장하는 함수
  Future<void> _saveQuizAttempt() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _results.isEmpty) return;

    final attemptData = {
      'userId': user.uid,
      'quizTitle': widget.quizTitle,
      'themeId': widget.theme?.themeId, // 테마가 있는 경우 ID 저장
      'timestamp': FieldValue.serverTimestamp(),
      'score': _results.where((r) => r.wasCorrect).length,
      'totalQuestions': _results.length,
      'results': _results.map((r) => r.toMap()).toList(),
    };

    try {
      await FirebaseFirestore.instance.collection('quiz_attempts').add(attemptData);
    } catch (e) {
      print('퀴즈 결과 저장 실패: $e');
      // 사용자에게 피드백을 주지 않아도 괜찮음 (백그라운드 작업)
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.quizTitle)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_allWords.isEmpty || _quizWords.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.quizTitle)),
        body: const Center(
          child: Text(
            '퀴즈를 생성할 단어가 없습니다.',
            style: TextStyle(fontSize: 18, color: Colors.red),
          ),
        ),
      );
    }

    if (_quizCompleted) {
      return Scaffold(
        appBar: AppBar(
          title: Text('${widget.quizTitle} 결과'),
          automaticallyImplyLeading: false,
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                '총 ${_results.length}문제 중 ${_results.where((r) => r.wasCorrect).length}개 정답!',
                style: AppTheme.themeData.textTheme.headlineMedium,
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: _results.length,
                itemBuilder: (context, index) {
                  final result = _results[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    color: result.wasCorrect ? Colors.green.shade50 : Colors.red.shade50,
                    child: ListTile(
                      leading: Icon(
                        result.wasCorrect ? Icons.check_circle : Icons.cancel,
                        color: result.wasCorrect ? Colors.green : Colors.red,
                      ),
                      title: Text(
                        result.questionWord.word,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('정답: ${result.correctAnswer}'),
                          if (!result.wasCorrect)
                            Text(
                              '선택한 답: ${result.selectedAnswer}',
                              style: const TextStyle(color: Colors.red),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    onPressed: _restartQuiz,
                    child: const Text('다시 시작'),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('퀴즈풀기 화면으로'),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final currentWord = _quizWords[_currentIndex];

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.quizTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.exit_to_app),
            onPressed: _exitQuiz,
            tooltip: '퀴즈 나가기',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '문제 ${_currentIndex + 1} / ${_quizWords.length}',
              style: AppTheme.themeData.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              child: Container(
                padding: const EdgeInsets.all(20),
                height: 150,
                alignment: Alignment.center,
                child: Text(
                  currentWord.word,
                  style: AppTheme.themeData.textTheme.displayMedium,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            const SizedBox(height: 30),
            ..._options.map((option) {
              final bool isSelected = option == _selectedAnswer;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isSelected ? AppTheme.primaryColor : Colors.grey[100],
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () => _selectAnswer(option),
                  child: Text(
                    option,
                    style: AppTheme.themeData.textTheme.headlineSmall?.copyWith(
                      color: isSelected ? Colors.white : AppTheme.primaryColor,
                    ),
                  ),
                ),
              );
            }).toList(),
            const Spacer(),
            ElevatedButton(
              onPressed: _selectedAnswer != null ? _nextQuestion : null,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                _currentIndex < _quizWords.length - 1 ? '다음 문제' : '결과 보기',
                style: AppTheme.themeData.textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}