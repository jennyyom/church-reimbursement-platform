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

  @override
  String get appTitle => '교회 경비 정산';

  @override
  String get approverDashboard => '승인자 대시보드';

  @override
  String get adminDashboard => '관리자 대시보드';

  @override
  String get reviewReceipts => '승인 대기 중인 영수증을 검토해주세요.';

  @override
  String get manageReimbursements => '전체 정산 내역을 관리합니다.';
}
