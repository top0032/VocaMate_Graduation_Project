import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'auth_check_screen.dart'; // 로그인 후 이동할 화면

class PhoneVerificationScreen extends StatefulWidget {
  final String email;
  final String password;
  final String phoneNumber;
  // final String name; // 💡 이름 필드 삭제

  const PhoneVerificationScreen({
    super.key,
    required this.email,
    required this.password,
    required this.phoneNumber,
    // required this.name, // 💡 생성자에서 삭제
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
    _verifyPhoneNumber();
  }

  @override
  void dispose() {
    _smsCodeController.dispose();
    super.dispose();
  }

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

          // 💡 인증 실패 원인에 따라 메시지 세분화
          String message = '인증 실패: ${e.message}';
          if (e.code == 'invalid-phone-number') {
            message = '유효하지 않은 전화번호 형식입니다.';
          } else if (e.code == 'too-many-requests') {
            message = '요청이 너무 많습니다. 잠시 후 다시 시도해주세요.';
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
      ).showSnackBar(SnackBar(content: Text('요청 중 오류 발생: $e')));
    }
  }

  void _signInAndRegister(BuildContext context) async {
    if (_verificationId == null) return;

    PhoneAuthCredential phoneCredential = PhoneAuthProvider.credential(
      verificationId: _verificationId!,
      smsCode: _smsCodeController.text,
    );

    if (widget.password.length < 6) {
      if (mounted)
        setState(() {
          _isLoading = false;
        });
      return;
    }

    try {
      if (mounted)
        setState(() {
          _isLoading = true;
        });

      // 이메일/비밀번호 계정 생성
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

      // 전화번호 인증 정보 연결
      await user.linkWithCredential(phoneCredential);

      // Firestore 저장 (이름 제외)
      await FirebaseFirestore.instance.collection('users').doc(userId).set({
        'email': widget.email,
        'phoneNumber': widget.phoneNumber,
        // 'name': widget.name, // 💡 이름 저장 삭제
        'role': 'user',
        'createdAt': FieldValue.serverTimestamp(),
      });

      await FirebaseAuth.instance.signOut();

      if (!mounted) return;
      // 로그인 화면으로 이동 (스택 비우기)
      Navigator.popUntil(context, (route) => route.isFirst);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ 회원가입 완료! 이제 이메일로 로그인하세요.')),
      );
    } on FirebaseAuthException catch (e) {
      String message = '인증 실패: ${e.message}';
      if (e.code == 'email-already-in-use') {
        message = '이미 사용 중인 이메일입니다.';
      } else if (e.code == 'credential-already-in-use') {
        message = '이미 등록된 전화번호입니다.';
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('오류 발생: $e')));
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
              Text('${widget.phoneNumber}로 발송된 인증번호를 입력하세요.'),
              const SizedBox(height: 20),
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
