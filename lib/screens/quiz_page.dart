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
  }) : assert(
         theme != null || words != null,
         'Either theme or words must be provided.',
       );

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
        // '나만의 단어장' 등 목록이 직접 제공된 경우
        fetchedWords = widget.words!;
      } else {
        // 테마 ID로 단어를 가져오는 경우
        fetchedWords = await _themeService.getWordsByTheme(
          widget.theme!.themeId,
        );
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('단어 로딩 중 오류가 발생했습니다: $e')));
      }
    }
  }

  void _prepareQuizWords() {
    _allWords.shuffle(_random);
    if (widget.numberOfQuestions > 0 &&
        widget.numberOfQuestions < _allWords.length) {
      _quizWords = _allWords.take(widget.numberOfQuestions).toList();
    } else {
      _quizWords = List.from(_allWords);
    }
  }

  void _generateQuestion() {
    if (_quizWords.isEmpty) return;

    final currentWord = _quizWords[_currentIndex];
    _correctAnswerMeaning = currentWord.meaning;

    // 오답 생성 로직
    List<String> incorrectMeanings = [];
    List<WordModel> otherWords = _allWords
        .where((word) => word.word != currentWord.word)
        .toList();
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('답변을 선택해주세요!')));
      return;
    }

    final currentWord = _quizWords[_currentIndex];
    final bool wasCorrect = _selectedAnswer == _correctAnswerMeaning;

    _results.add(
      QuizResult(
        questionWord: currentWord,
        selectedAnswer: _selectedAnswer!,
        correctAnswer: _correctAnswerMeaning!,
        wasCorrect: wasCorrect,
      ),
    );

    if (_currentIndex >= _quizWords.length - 1) {
      // 퀴즈 종료 및 결과 저장
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
      if (_results.isNotEmpty) {
        _saveQuizAttempt();
      }
      setState(() {
        _quizCompleted = true;
      });
    }
  }

  Future<void> _saveQuizAttempt() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _results.isEmpty) return;

    final attemptData = {
      'userId': user.uid,
      'quizTitle': widget.quizTitle,
      'themeId': widget.theme?.themeId,
      'timestamp': FieldValue.serverTimestamp(),
      'score': _results.where((r) => r.wasCorrect).length,
      'totalQuestions': _results.length,
      'results': _results.map((r) => r.toMap()).toList(),
    };

    try {
      await FirebaseFirestore.instance
          .collection('quiz_attempts')
          .add(attemptData);
    } catch (e) {
      print('퀴즈 결과 저장 실패: $e');
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

    // --- 퀴즈 결과 화면 ---
    if (_quizCompleted) {
      return Scaffold(
        appBar: AppBar(
          title: Text('${widget.quizTitle} 결과'),
          automaticallyImplyLeading: false,
        ),
        body: SafeArea(
          // 💡 SafeArea 적용
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  '총 ${_results.length}문제 중 ${_results.where((r) => r.wasCorrect).length}개 정답!',
                  style: AppTheme.themeData.textTheme.headlineSmall?.copyWith(
                    color: Colors.blueGrey,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: _results.length,
                  itemBuilder: (context, index) {
                    final result = _results[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      color: result.wasCorrect
                          ? Colors.green.shade50
                          : Colors.red.shade50,
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
                                style: const TextStyle(
                                  color: Colors.red,
                                  fontWeight: FontWeight.bold,
                                ),
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
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                      ),
                      child: const Text(
                        '다시 시작',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueGrey,
                      ),
                      child: const Text(
                        '테마 선택으로',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    // --- 퀴즈 진행 화면 ---
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
      // 💡 1. body 전체를 SafeArea로 감싸서 상단/하단 침범 방지
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 진행 상황 표시
              LinearProgressIndicator(
                value: (_currentIndex + 1) / _quizWords.length,
                backgroundColor: Colors.grey[300],
                color: AppTheme.primaryColor,
              ),
              const SizedBox(height: 10),
              Text(
                '문제 ${_currentIndex + 1} / ${_quizWords.length}',
                style: AppTheme.themeData.textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),

              // 문제 카드
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
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
              const SizedBox(height: 20),

              // 보기 목록 (Expanded로 남은 공간 차지하게 함)
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: _options.map((option) {
                      final bool isSelected = option == _selectedAnswer;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isSelected
                                  ? AppTheme.primaryColor
                                  : Colors.white,
                              foregroundColor: isSelected
                                  ? Colors.white
                                  : AppTheme.primaryColor,
                              padding: const EdgeInsets.symmetric(vertical: 15),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                                side: BorderSide(color: AppTheme.primaryColor),
                              ),
                              elevation: isSelected ? 2 : 0,
                            ),
                            onPressed: () => _selectAnswer(option),
                            child: Text(
                              option,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),

              // 💡 2. 하단 다음 버튼 (SafeArea 내부라 짤리지 않음)
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: _selectedAnswer != null ? _nextQuestion : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _selectedAnswer != null
                        ? Colors.blueGrey
                        : Colors.grey,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    _currentIndex < _quizWords.length - 1 ? '다음 문제' : '결과 보기',
                    style: const TextStyle(
                      fontSize: 18,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
