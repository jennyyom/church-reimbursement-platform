import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';   //firebase 로그인 기능 가져오기
import 'package:cloud_firestore/cloud_firestore.dart';
import 'home_page.dart'; // UserHomePage, ApproverHomePage, AdminHomePage 있는 파일
import 'signup_page.dart';

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

  Future<void> _signIn() async {
  setState(() => _isLoading = true);
  try {
    // 1. 기존 로그인 (그대로 유지)
    final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
      email: _emailController.text.trim(),
      password: _passwordController.text.trim(),
    );

    // 2. 로그인 성공 → Firestore에서 role 읽기
    final uid = credential.user!.uid;
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();

    // 3. 문서가 없으면 최초 로그인 → role: 'user'로 자동 생성
    if (!doc.exists) {
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'email': _emailController.text.trim(),
        'role': 'user', // 기본값
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    // 4. role 값 읽기 (없으면 'user' 기본값)
    final role = doc.exists ? doc['role'] : 'user';

    // 5. role에 따라 화면 이동
    if (!mounted) return;
    if (role == 'admin') {
      Navigator.pushReplacement(context,
          MaterialPageRoute(builder: (_) => AdminHomePage()));
    } else if (role == 'approver') {
      Navigator.pushReplacement(context,
          MaterialPageRoute(builder: (_) => ApproverHomePage()));
    } else {
      Navigator.pushReplacement(context,
          MaterialPageRoute(builder: (_) => UserHomePage()));
    }

  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Login failed: $e')),
    );
  }
  setState(() => _isLoading = false);
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

                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const SignupPage()),
                      );
                    },
                    child: const Text("Don't have an account? Sign up"),
                  ),
          ],
        ),
      ),
    );
  }
} 