import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart'; //firebase 가져오기
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_localizations/flutter_localizations.dart'; // 추가
import 'package:church_reimbursement/l10n/app_localizations.dart';      // 추가
import 'firebase_options.dart';    
import 'pages/login_page.dart';                //연결정보 가져오기
import 'pages/home_page.dart';

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

      // 다국어 설정 추가
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en'), // 영어
        Locale('ko'), // 한국어
        Locale('sw'), // 스와힐리어
      ],

      home: const LoginPage(), // role 분기는 LoginPage._signIn()이 처리
    );
  }
}