import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:church_reimbursement/l10n/app_localizations.dart';
import 'home_page.dart';
import 'signup_page.dart';
import '../main.dart';
import 'approver_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true; // 비밀번호 표시 토글

  // 컨트롤러 메모리 해제
  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    setState(() => _isLoading = true);
    try {
      // 1. Firebase Auth 로그인
      final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      // 2. Firestore에서 사용자 문서 조회
      final uid = credential.user!.uid;
      final docRef = FirebaseFirestore.instance.collection('users').doc(uid);
      final doc = await docRef.get();

      // 3. 최초 로그인이면 member로 자동 생성
      if (!doc.exists) {
        await docRef.set({
          'email': _emailController.text.trim(),
          'role': 'member',
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      // 4. role 읽기 — 필드 없으면 member 기본값
      final role = doc.exists ? (doc.data()?['role'] ?? 'member') : 'member';

      // 5. role에 따라 홈 화면으로 이동
      if (!mounted) return;
      if (role == 'admin') {
        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (_) => AdminHomePage()));
      } else if (role == 'approver') {
        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (_) => const ApproverPage()));
      } else {
        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (_) => UserHomePage()));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Login failed: $e')),
      );
    } finally {
      // 성공/실패 관계없이 로딩 상태 해제
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: Colors.indigo.shade50,
      appBar: AppBar(
        title: Text(l10n.signInTitle),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        actions: [
          // 언어 선택 버튼
          IconButton(
            icon: const Icon(Icons.language),
            onPressed: () => showModalBottomSheet(
              context: context,
              builder: (_) => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    title: const Text('English'),
                    onTap: () {
                      ChurchReimbursementApp.of(context)
                          ?.setLocale(const Locale('en'));
                      Navigator.pop(context);
                    },
                  ),
                  ListTile(
                    title: const Text('한국어'),
                    onTap: () {
                      ChurchReimbursementApp.of(context)
                          ?.setLocale(const Locale('ko'));
                      Navigator.pop(context);
                    },
                  ),
                  ListTile(
                    title: const Text('Kiswahili'),
                    onTap: () {
                      ChurchReimbursementApp.of(context)
                          ?.setLocale(const Locale('sw'));
                      Navigator.pop(context);
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 이메일 입력
            TextField(
              controller: _emailController,
              decoration: InputDecoration(
                labelText: l10n.email,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            // 비밀번호 입력 (보이기/숨기기 토글)
            TextField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              decoration: InputDecoration(
                labelText: l10n.password,
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(_obscurePassword
                      ? Icons.visibility_off
                      : Icons.visibility),
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
            ),
            const SizedBox(height: 24),
            // 로그인 버튼 (로딩 중이면 스피너)
            _isLoading
                ? const CircularProgressIndicator()
                : SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _signIn,
                      child: Text(l10n.signInTitle),
                    ),
                  ),
            const SizedBox(height: 16),
            // 회원가입 페이지로 이동
            TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SignupPage()),
              ),
              child: Text(l10n.noAccount),
            ),
          ],
        ),
      ),
    );
  }
}