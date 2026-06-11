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
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    setState(() => _isLoading = true);
    try {
      final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      final uid = credential.user!.uid;
      final docRef = FirebaseFirestore.instance.collection('users').doc(uid);
      final doc = await docRef.get();

      if (!doc.exists) {
        await docRef.set({
          'email': _emailController.text.trim(),
          'role': 'member',
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      final role = doc.exists ? (doc.data()?['role'] ?? 'member') : 'member';

      if (!mounted) return;
      if (role == 'admin') {
        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (_) => UserHomePage()));
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
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 언어 선택 바텀시트 (공통)
  void _showLanguagePicker() {
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
  }

  // 공통 폼 위젯
  Widget _buildForm(BuildContext context, {bool isWeb = false}) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (isWeb) ...[
          // 웹: 폼 상단에 로고 + 타이틀
          const Icon(Icons.church, size: 40, color: Colors.indigo),
          const SizedBox(height: 8),
          const Text(
            'Church Reimbursement',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.indigo,
            ),
          ),
          const SizedBox(height: 24),
        ] else ...[
          // 모바일: 바텀시트 핸들
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(
            labelText: l10n.email,
            prefixIcon: const Icon(Icons.email_outlined),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            filled: true,
            fillColor: Colors.grey.shade50,
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _passwordController,
          obscureText: _obscurePassword,
          decoration: InputDecoration(
            labelText: l10n.password,
            prefixIcon: const Icon(Icons.lock_outline),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            filled: true,
            fillColor: Colors.grey.shade50,
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword ? Icons.visibility_off : Icons.visibility,
              ),
              onPressed: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
            ),
          ),
        ),
        const SizedBox(height: 20),
        _isLoading
            ? const Center(child: CircularProgressIndicator())
            : ElevatedButton(
                onPressed: _signIn,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  l10n.signInTitle,
                  style: const TextStyle(fontSize: 15),
                ),
              ),
        const SizedBox(height: 12),
        Center(
          child: TextButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SignupPage()),
            ),
            child: Text(
              l10n.noAccount,
              style: const TextStyle(color: Colors.indigo),
            ),
          ),
        ),
      ],
    );
  }

  // 모바일 레이아웃 
  Widget _buildMobileLayout(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: Colors.indigo,
      body: Stack(
        children: [
          // 상단 인디고 영역 — 로고 + 타이틀
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            bottom: 260,
            child: SafeArea(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // 언어 버튼 (우측 상단)
                  Align(
                    alignment: Alignment.topRight,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 16, top: 8),
                      child: IconButton(
                        icon: const Icon(Icons.language,
                            color: Colors.white70, size: 22),
                        onPressed: _showLanguagePicker,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Icon(Icons.church,
                        size: 34, color: Colors.white),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Church Reimbursement',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    l10n.signInTitle,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 13,
                    ),
                  ),
                  const Spacer(),
                ],
              ),
            ),
          ),
          // 하단 흰색 바텀시트
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
              child: _buildForm(context, isWeb: false),
            ),
          ),
        ],
      ),
    );
  }

  // 웹/태블릿 레이아웃 — 가운데 카드
  Widget _buildWebLayout(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.indigo.shade50,
      appBar: AppBar(
        title: const Text('Church Reimbursement'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.language),
            onPressed: _showLanguagePicker,
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Container(
            width: 400,
            margin: const EdgeInsets.symmetric(vertical: 40),
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: _buildForm(context, isWeb: true),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // 600px 기준으로 모바일/웹 분기
        if (constraints.maxWidth < 600) {
          return _buildMobileLayout(context);
        } else {
          return _buildWebLayout(context);
        }
      },
    );
  }
}