import 'package:flutter/material.dart';
import 'login_page.dart';
import 'package:firebase_core/firebase_core.dart'; //firebase 가져오기
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';                    //연결정보 가져오기
import 'home_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();       //flutter 준비된 떄까지 기다리기

  await Firebase.initializeApp(                    //firebase 시작
    options: DefaultFirebaseOptions.currentPlatform,   //플랫폼에 맞는 설정 사용
  );

  runApp(const ChurchReimbursementApp());          //앱 실행
}

class ChurchReimbursementApp extends StatelessWidget {
  const ChurchReimbursementApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Church Reimbursement',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      // 로그인 상태에 따라 화면 자동 전환
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const CircularProgressIndicator();
          }
          if (snapshot.hasData) {
            return const HomePage(); // 로그인 됐으면 홈으로
          }
          return const LoginPage(); // 로그인 안 됐으면 로그인 페이지로
        },
      ),
    );
  }
}