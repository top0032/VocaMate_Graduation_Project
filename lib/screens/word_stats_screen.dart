import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme.dart';

// 단어 통계를 저장하기 위한 모델
class WordStat {
  final String word;
  int totalAttempts = 0;
  int incorrectAttempts = 0;

  WordStat(this.word);

  int get correctAttempts => totalAttempts - incorrectAttempts;
  double get incorrectRate => totalAttempts == 0 ? 0.0 : (incorrectAttempts / totalAttempts) * 100;
  double get correctRate => totalAttempts == 0 ? 0.0 : (correctAttempts / totalAttempts) * 100;
}

// 정렬 방식을 위한 Enum
enum SortType { byAttempts, byCorrectRate, byIncorrectRate }

class WordStatsScreen extends StatefulWidget {
  const WordStatsScreen({super.key});

  @override
  State<WordStatsScreen> createState() => _WordStatsScreenState();
}

class _WordStatsScreenState extends State<WordStatsScreen> {
  bool _isLoading = true;
  final Map<String, WordStat> _wordStats = {};
  SortType _sortType = SortType.byAttempts; // 현재 정렬 방식 상태

  @override
  void initState() {
    super.initState();
    _calculateStats();
  }

  Future<void> _calculateStats() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    final attemptsSnapshot = await FirebaseFirestore.instance
        .collection('quiz_attempts')
        .where('userId', isEqualTo: user.uid)
        .get();

    for (var attemptDoc in attemptsSnapshot.docs) {
      final results = attemptDoc.data()['results'] as List<dynamic>? ?? [];
      for (var result in results) {
        final word = result['word'] as String?;
        if (word == null) continue;

        _wordStats.putIfAbsent(word, () => WordStat(word));
        final stat = _wordStats[word]!;

        stat.totalAttempts++;
        if (result['wasCorrect'] == false) {
          stat.incorrectAttempts++;
        }
      }
    }

    setState(() {
      _isLoading = false;
    });
  }

  // 맞춤/틀림 비율을 보여주는 스탯 바 위젯 (더 작게 조정)
  Widget _buildStatBar(WordStat stat) {
    int correct = stat.correctAttempts;
    int incorrect = stat.incorrectAttempts;
    int total = stat.totalAttempts;

    if (total == 0) return const SizedBox.shrink();

    return ClipRRect(
      borderRadius: const BorderRadius.all(Radius.circular(8)),
      child: SizedBox(
        height: 16, // 높이 조정
        width: 100, // 고정 너비 설정
        child: Row(
          children: [
            if (correct > 0)
              Expanded(
                flex: correct,
                child: Container(color: Colors.green),
              ),
            if (incorrect > 0)
              Expanded(
                flex: incorrect,
                child: Container(color: Colors.red),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sortedStats = _wordStats.values.toList();
    if (_sortType == SortType.byAttempts) {
      sortedStats.sort((a, b) => b.totalAttempts.compareTo(a.totalAttempts));
    } else if (_sortType == SortType.byCorrectRate) {
      sortedStats.sort((a, b) {
        int rateCompare = b.correctRate.compareTo(a.correctRate);
        if (rateCompare == 0) { // 정답률이 같으면 푼 횟수가 많은 것을 우선
          return b.totalAttempts.compareTo(a.totalAttempts);
        }
        return rateCompare;
      });
    }
    else { // SortType.byIncorrectRate
      sortedStats.sort((a, b) {
        int rateCompare = b.incorrectRate.compareTo(a.incorrectRate);
        if (rateCompare == 0) { // 오답률이 같으면 푼 횟수가 많은 것을 우선
          return b.totalAttempts.compareTo(a.totalAttempts);
        }
        return rateCompare;
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('단어 통계'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _wordStats.isEmpty
              ? const Center(
                  child: Text(
                    '아직 통계를 낼 퀴즈 기록이 없습니다.',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                )
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16.0),
                      child: ToggleButtons(
                        isSelected: [
                          _sortType == SortType.byAttempts,
                          _sortType == SortType.byCorrectRate, // 정답률 높은 순
                          _sortType == SortType.byIncorrectRate,
                        ],
                        onPressed: (index) {
                          setState(() {
                            if (index == 0) {
                              _sortType = SortType.byAttempts;
                            } else if (index == 1) {
                              _sortType = SortType.byCorrectRate;
                            } else {
                              _sortType = SortType.byIncorrectRate;
                            }
                          });
                        },
                        borderRadius: BorderRadius.circular(8),
                        children: const [
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 12.0),
                            child: Text('많이 푼 단어 순'),
                          ),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 12.0),
                            child: Text('정답률 높은 순'), // 정답률 높은 순
                          ),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 12.0),
                            child: Text('오답률 높은 순'),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        itemCount: sortedStats.length,
                        itemBuilder: (context, index) {
                          final stat = sortedStats[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(stat.word, style: AppTheme.themeData.textTheme.titleLarge),
                                      CircleAvatar(
                                        radius: 12,
                                        backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                                        child: Text(
                                          '${index + 1}',
                                          style: TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold, fontSize: 12),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  _buildStatBar(stat),
                                  const SizedBox(height: 4),
                                  Text(
                                    '총 ${stat.totalAttempts}회 | 정답 ${stat.correctAttempts}회 | 오답 ${stat.incorrectAttempts}회 | 정답률: ${stat.correctRate.toStringAsFixed(1)}%',
                                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
    );
  }
}
