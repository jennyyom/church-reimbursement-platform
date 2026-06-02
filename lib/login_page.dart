import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';   //firebase 로그인 기능 가져오기

//StatefulWidget 상태 변화가 있는 화면(입력값 로딩등) 원래는 StatelessWidget였음
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  //이메일, 비밀번호 입력창 값을 읽기 위한 컨트롤러
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  //로딩 중인지 아닌지 상태
  bool _isLoading = false;

  //로그인 버튼 눌렀을 때 실행되는 함수
  Future<void> _signIn() async {
    setState(() => _isLoading = true); //로딩 시작
    try {
      //firebase에 이메일,비밀번호 로그인 요청
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
    } catch (e) {
      //로그인 실패시 화면 아래에 에러 메세지 표시
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Login failed: $e')),
      );
    }
    setState(() => _isLoading = false); //로딩 끝
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.indigo.shade50,
      appBar: AppBar(
        title: const Text('Sign In'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _emailController,  //입력값 연결
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,   //입력값 연결
              obscureText: true,                 //비밀번호 가리기
              decoration: const InputDecoration(
                labelText: 'Password',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            //로딩 중이면 스피너, 아니면 버튼 표시
            _isLoading
                ? const CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: _signIn,   //버튼 누르면 _signIn 실행
                    child: const Text('Sign In'),
                  ),
          ],
        ),
      ),
    );
  }
}