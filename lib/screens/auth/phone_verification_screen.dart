import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PhoneVerificationScreen extends StatefulWidget {
  final String email;
  final String password;
  final String phoneNumber;

  const PhoneVerificationScreen({
    super.key,
    required this.email,
    required this.password,
    required this.phoneNumber,
  });

  @override
  State<PhoneVerificationScreen> createState() =>
      _PhoneVerificationScreenState();
}

class _PhoneVerificationScreenState extends State<PhoneVerificationScreen> {
  final TextEditingController _smsCodeController = TextEditingController();
  String? _verificationId;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _verifyPhoneNumber(); // 화면 시작 시 인증번호 요청
  }

  @override
  void dispose() {
    _smsCodeController.dispose();
    super.dispose();
  }

  // Firebase에 인증번호 요청 로직 (이전과 동일)
  void _verifyPhoneNumber() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: widget.phoneNumber,
        timeout: const Duration(minutes: 1),
        verificationCompleted: (PhoneAuthCredential credential) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('자동 인증 완료. 회원가입을 진행합니다.')),
          );
          _smsCodeController.text = credential.smsCode ?? '';
          _signInAndRegister(context);
        },
        verificationFailed: (FirebaseAuthException e) {
          if (!mounted) return;
          setState(() {
            _isLoading = false;
          });
          String message = '인증 실패: ${e.message}';
          if (e.code == 'invalid-phone-number') {
            message = '유효하지 않은 전화번호 형식입니다.';
          }
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(message)));
        },
        codeSent: (String verificationId, int? resendToken) {
          if (!mounted) return;
          setState(() {
            _verificationId = verificationId;
            _isLoading = false;
          });
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('인증번호가 발송되었습니다.')));
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          if (!mounted) return;
          setState(() {
            _verificationId = verificationId;
            _isLoading = false;
          });
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      print('verifyPhoneNumber Uncaught Error: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('요청 중 예기치 않은 오류 발생: $e')));
    }
  }

  // 💡 최종 안정화 로직: 이메일 계정 생성 후 전화번호 인증 정보를 연결 (updateEmail 오류 완벽 회피)
  void _signInAndRegister(BuildContext context) async {
    if (_verificationId == null) return;

    // 1. 전화번호 자격 증명 생성
    PhoneAuthCredential phoneCredential = PhoneAuthProvider.credential(
      verificationId: _verificationId!,
      smsCode: _smsCodeController.text,
    );

    // 2. 비밀번호 길이 재확인
    if (widget.password.length < 6) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      return;
    }

    try {
      if (mounted) {
        setState(() {
          _isLoading = true;
        });
      }

      // 3. 🚨 핵심: 이메일/비밀번호 계정을 먼저 생성합니다. (이 방식으로 Auth에 이메일/비번 등록)
      UserCredential userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
            email: widget.email,
            password: widget.password,
          );

      User? user = userCredential.user;
      if (user == null) {
        throw FirebaseAuthException(code: 'user-null', message: '계정 생성 실패.');
      }
      String userId = user.uid;

      // 4. 생성된 계정에 전화번호 인증 정보를 연결합니다. (linkWithCredential 사용)
      // 이 과정은 단순한 인증 방식 추가이므로 updateEmail보다 훨씬 안정적입니다.
      await user.linkWithCredential(phoneCredential);

      // 5. Firestore에 사용자 프로필 저장
      await FirebaseFirestore.instance.collection('users').doc(userId).set({
        'email': widget.email,
        'phoneNumber': widget.phoneNumber,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 6. 계정 생성 및 정보 저장이 완료되었으므로 세션 종료
      await FirebaseAuth.instance.signOut();

      // 7. 모든 화면을 닫고 로그인 화면으로 복귀
      Navigator.popUntil(context, (route) => route.isFirst);

      // 8. 성공 메시지 표시
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ 회원가입이 승인되었습니다. 이제 이메일과 비밀번호로 로그인할 수 있습니다.'),
        ),
      );
    } on FirebaseAuthException catch (e) {
      String message = '인증 실패: ${e.message}';
      if (e.code == 'email-already-in-use') {
        message = '이미 사용 중인 이메일입니다. 로그인 해주세요.';
      } else if (e.code == 'operation-not-allowed') {
        message = 'Firebase 설정에서 이메일/비밀번호 로그인이 활성화되지 않았습니다.';
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } catch (e) {
      String message = '예기치 않은 오류 발생: $e';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('휴대폰 본인 인증')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else ...[
              Text('입력하신 번호 ${widget.phoneNumber}로 인증번호가 발송되었습니다.'),
              TextField(
                controller: _smsCodeController,
                decoration: const InputDecoration(labelText: '인증번호 6자리 입력'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: (_verificationId != null && !_isLoading)
                      ? () => _signInAndRegister(context)
                      : null,
                  child: const Text(
                    '인증 확인 및 회원가입 완료',
                    style: TextStyle(color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.secondary,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
