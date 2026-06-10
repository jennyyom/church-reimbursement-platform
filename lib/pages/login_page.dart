import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';        // firebase 로그인 기능
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:church_reimbursement/l10n/app_localizations.dart'; // 번역 추가
import 'home_page.dart';   // UserHomePage, ApproverHomePage, AdminHomePage
import 'signup_page.dart';
import '../main.dart';
import 'approver_page.dart';

// StatefulWidget - 상태 변화가 있는 화면 (입력값, 로딩 등)
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  // 이메일, 비밀번호 입력창 값을 읽기 위한 컨트롤러
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  // 로딩 중인지 상태
  bool _isLoading = false;

  Future<void> _signIn() async {
    setState(() => _isLoading = true);
    try {
      // 1. 로그인
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

      // 3. 문서가 없으면 최초 로그인 → member로 자동 생성
      if (!doc.exists) {
        await FirebaseFirestore.instance.collection('users').doc(uid).set({
          'email': _emailController.text.trim(),
          'role': 'member', // 기본값 (user → member로 통일)
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      // 4. role 값 읽기 (없으면 'member' 기본값)
      final role = doc.exists ? doc['role'] : 'member';

      // 5. role에 따라 화면 이동
      if (!mounted) return;
      if (role == 'admin') {
        Navigator.pushReplacement(context,
            MaterialPageRoute(builder: (_) => AdminHomePage()));
      } else if (role == 'approver') {
        Navigator.pushReplacement(context,
            MaterialPageRoute(builder: (_) => const ApproverPage()));
      } else {
        Navigator.pushReplacement(context,
            MaterialPageRoute(builder: (_) => UserHomePage()));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Login failed: $e')),
      );
    }
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!; // 번역 키 접근용
    return Scaffold(
      backgroundColor: Colors.indigo.shade50,
      appBar: AppBar(
  title: Text(l10n.signInTitle),
  backgroundColor: Colors.indigo,
  foregroundColor: Colors.white,
  actions: [
    IconButton(
      icon: const Icon(Icons.language),
      onPressed: () {
        showModalBottomSheet(
          context: context,
          builder: (_) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text('English'),
                onTap: () {
                  ChurchReimbursementApp.of(context)?.setLocale(const Locale('en'));
                  Navigator.pop(context);
                },
              ),
              ListTile(
                title: const Text('한국어'),
                onTap: () {
                  ChurchReimbursementApp.of(context)?.setLocale(const Locale('ko'));
                  Navigator.pop(context);
                },
              ),
              ListTile(
                title: const Text('Kiswahili'),
                onTap: () {
                  ChurchReimbursementApp.of(context)?.setLocale(const Locale('sw'));
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    ),
  ],
),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _emailController, // 입력값 연결
              decoration: InputDecoration(
                labelText: l10n.email, // 번역 적용
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController, // 입력값 연결
              obscureText: true,               // 비밀번호 가리기
              decoration: InputDecoration(
                labelText: l10n.password, // 번역 적용
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            // 로딩 중이면 스피너, 아니면 버튼 표시
            _isLoading
                ? const CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: _signIn,
                    child: Text(l10n.signInTitle), // 번역 적용
                  ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SignupPage()),
                );
              },
              child: Text(l10n.noAccount), // 번역 적용
            ),
          ],
        ),
      ),
    );
  }
}