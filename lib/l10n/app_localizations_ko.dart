// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Korean (`ko`).
class AppLocalizationsKo extends AppLocalizations {
  AppLocalizationsKo([String locale = 'ko']) : super(locale);

  @override
  String get signIn => '로그인';

  @override
  String get signOut => '로그아웃';

  @override
  String get submitReceipt => '영수증 제출';

  @override
  String get amount => '금액';

  @override
  String get date => '날짜';

  @override
  String get description => '설명';

  @override
  String get category => '카테고리';

  @override
  String get pending => '대기중';

  @override
  String get approved => '승인됨';

  @override
  String get rejected => '거절됨';

  @override
  String get approve => '승인';

  @override
  String get reject => '거절';
}
