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
      home: const LoginPage(), // role 분기는 LoginPage._signIn()이 처리
    );
  }
}