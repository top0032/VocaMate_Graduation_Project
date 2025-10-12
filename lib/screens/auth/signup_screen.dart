import 'package:flutter/material.dart';
import 'phone_verification_screen.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _goToVerification(BuildContext context) {
    if (!_formKey.currentState!.validate()) return;

    // 비밀번호 길이 검사 (Firebase 최소 요구 사항: 6자)
    if (_passwordController.text.trim().length < 6) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('비밀번호는 최소 6자 이상이어야 합니다!')));
      return;
    }

    // 전화번호 형식 검사 (국제 코드 +82 포함 여부)
    String phoneNumber = _phoneController.text.trim();
    if (!phoneNumber.startsWith('+')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('전화번호는 국제 표준 형식(예: +8210xxxx)으로 입력해야 합니다.'),
        ),
      );
      return;
    }

    // 모든 검사를 통과하면 다음 화면으로 데이터를 전달
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PhoneVerificationScreen(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
          phoneNumber: phoneNumber,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('VocaMate 회원가입')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(labelText: '이메일'),
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) => (value == null || !value.contains('@'))
                      ? '유효한 이메일 주소를 입력하세요.'
                      : null,
                ),
                const SizedBox(height: 15),
                TextFormField(
                  controller: _passwordController,
                  decoration: const InputDecoration(labelText: '비밀번호 (최소 6자)'),
                  obscureText: true,
                  validator: (value) => (value == null || value.isEmpty)
                      ? '비밀번호를 입력해 주세요.'
                      : null,
                ),
                const SizedBox(height: 15),
                TextFormField(
                  controller: _phoneController,
                  decoration: const InputDecoration(
                    labelText: '휴대폰 번호 (예: +8210xxxx)',
                  ),
                  keyboardType: TextInputType.phone,
                  validator: (value) => (value == null || value.isEmpty)
                      ? '휴대폰 번호를 입력해 주세요.'
                      : null,
                ),
                const SizedBox(height: 30),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => _goToVerification(context),
                    child: const Text(
                      '3. 본인 인증하기',
                      style: TextStyle(fontSize: 18, color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.secondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
