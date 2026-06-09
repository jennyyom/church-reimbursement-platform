import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';           // firebase 가져오기
import 'package:flutter_localizations/flutter_localizations.dart'; // 다국어 지원
import 'package:church_reimbursement/l10n/app_localizations.dart'; // 번역 파일
import 'firebase_options.dart';                              // 연결정보 가져오기
import 'pages/login_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();                 // flutter 준비될 때까지 기다리기
  await Firebase.initializeApp(                              // firebase 시작
    options: DefaultFirebaseOptions.currentPlatform,         // 플랫폼에 맞는 설정 사용
  );
  runApp(const ChurchReimbursementApp());                    // 앱 실행
}

// StatefulWidget으로 변경 - 언어 설정을 상태로 관리하기 위해
class ChurchReimbursementApp extends StatefulWidget {
  const ChurchReimbursementApp({super.key});

  // 앱 어디서든 언어 변경할 수 있도록 접근자 제공
  static _ChurchReimbursementAppState? of(BuildContext context) =>
      context.findAncestorStateOfType<_ChurchReimbursementAppState>();

  @override
  State<ChurchReimbursementApp> createState() =>
      _ChurchReimbursementAppState();
}

class _ChurchReimbursementAppState extends State<ChurchReimbursementApp> {
  Locale _locale = const Locale('en');                       // 기본 영어

  // 언어 변경 함수 - 앱 어디서든 호출 가능
  void setLocale(Locale locale) {
    setState(() => _locale = locale);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Church Reimbursement',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      locale: _locale,                                       // 현재 선택된 언어
      // 다국어 설정
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en'),                                        // 영어
        Locale('ko'),                                        // 한국어
        Locale('sw'),                                        // 스와힐리어
      ],
      home: const LoginPage(),                              // role 분기는 LoginPage._signIn()이 처리
    );
  }
}