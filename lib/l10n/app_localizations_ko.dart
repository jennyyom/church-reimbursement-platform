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
  String get description => '설명 (선택사항)';

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

  @override
  String get email => '이메일';

  @override
  String get password => '비밀번호';

  @override
  String get signInTitle => '로그인';

  @override
  String get noAccount => '계정이 없으신가요? 회원가입';

  @override
  String get createAccount => '계정 만들기';

  @override
  String get name => '이름';

  @override
  String get inviteCode => '초대 코드';

  @override
  String get selectImage => '이미지 선택';

  @override
  String get uploadFailed => '업로드 실패';

  @override
  String get receiptSubmitted => '영수증이 제출되었습니다!';

  @override
  String get submitReceiptTitle => '영수증 제출';

  @override
  String get noImageSelected => '이미지가 선택되지 않았습니다';

  @override
  String get invalidInviteCode => '잘못된 초대 코드입니다';

  @override
  String get signupFailed => '회원가입 실패';
}
