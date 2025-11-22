import 'package:flutter/material.dart';
import 'dart:math';

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
}

class QuizPage extends StatefulWidget {
  final ThemeModel theme;
  final int numberOfQuestions;

  const QuizPage({
    super.key,
    required this.theme,
    required this.numberOfQuestions,
  });

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
      final fetchedWords = await _themeService.getWordsByTheme(widget.theme.themeId);
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
      // ... (error handling)
    }
  }

  void _prepareQuizWords() {
    _allWords.shuffle(_random);
    if (widget.numberOfQuestions > 0 && widget.numberOfQuestions < _allWords.length) {
      _quizWords = _allWords.take(widget.numberOfQuestions).toList();
    } else {
      _quizWords = _allWords;
    }
  }

  void _generateQuestion() {
    if (_quizWords.isEmpty) return;

    final currentWord = _quizWords[_currentIndex];
    _correctAnswerMeaning = currentWord.meaning;

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

  // 💡 사용자가 답을 선택하면, 선택된 답만 상태에 저장
  void _selectAnswer(String selectedMeaning) {
    setState(() {
      _selectedAnswer = selectedMeaning;
    });
  }

  // 💡 '다음' 버튼을 눌렀을 때 채점 및 결과 기록
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

    setState(() {
      _currentIndex++;
      if (_currentIndex < _quizWords.length) {
        _generateQuestion();
      } else {
        _quizCompleted = true;
      }
    });
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
      setState(() {
        _quizCompleted = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text('${widget.theme.name} 퀴즈')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_allWords.isEmpty || _quizWords.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text('${widget.theme.name} 퀴즈')),
        body: const Center(
          child: Text(
            '이 테마에 퀴즈를 생성할 단어가 없습니다.',
            style: TextStyle(fontSize: 18, color: Colors.red),
          ),
        ),
      );
    }

    if (_quizCompleted) {
      return Scaffold(
        appBar: AppBar(
          title: Text('${widget.theme.name} 퀴즈 결과'),
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
                    child: const Text('테마 선택으로'),
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
        title: Text('${widget.theme.name} 퀴즈'),
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
              // 💡 선택된 옵션인지 확인
              final bool isSelected = option == _selectedAnswer;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isSelected ? AppTheme.primaryColor : Colors.grey[100], // 선택 시 파랑, 미선택 시 살짝 어두운 흰색
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  // 💡 항상 답변을 선택/변경할 수 있도록 함
                  onPressed: () => _selectAnswer(option),
                  child: Text(
                    option,
                    style: AppTheme.themeData.textTheme.headlineSmall?.copyWith(
                      color: isSelected ? Colors.white : AppTheme.primaryColor, // 💡 글씨색 명시적 지정
                    ),
                  ),
                ),
              );
            }).toList(),
            const Spacer(),
            ElevatedButton(
              // 💡 답변을 선택해야 '다음' 버튼 활성화
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