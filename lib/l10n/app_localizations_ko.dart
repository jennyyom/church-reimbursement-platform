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
  String get date => '날짜';

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
  String approverDashboardWithName(String name) {
    return '$name님의 승인자 대시보드';
  }

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

  @override
  String get amount => '금액';

  @override
  String get description => '설명 (선택사항)';

  @override
  String greeting(String name) {
    return '안녕하세요, $name님! 👋';
  }

  @override
  String get friendFallback => '성도';

  @override
  String get tapToUpload => '눌러서 업로드';

  @override
  String get myReceipts => '내 영수증';

  @override
  String get filterAll => '전체';

  @override
  String get noReceiptsYet => '아직 영수증이 없습니다';

  @override
  String get receiptFallback => '영수증';

  @override
  String get deleteReceiptTitle => '이 영수증을 삭제할까요?';

  @override
  String get deleteReceiptMessage => '내 목록에서 삭제됩니다.';

  @override
  String get cancel => '취소';

  @override
  String get delete => '삭제';

  @override
  String get takePhoto => '사진 찍기';

  @override
  String get chooseFromGallery => '갤러리에서 선택';

  @override
  String get invalidImageFile => '올바른 이미지 파일이 아닌 것 같습니다. 영수증 사진을 선택해주세요.';

  @override
  String get imageTooLarge => '이미지가 너무 큽니다. 5MB 이하의 이미지를 선택해주세요.';

  @override
  String get processReceiptFailed => '영수증 처리 실패';

  @override
  String get readingAmount => '영수증에서 금액을 읽는 중…';

  @override
  String get departmentLabel => '부서 *';

  @override
  String get departmentHelper => '이 지출을 누가 승인할지 정합니다';

  @override
  String get selectDepartmentFirst => '제출하기 전에 부서를 선택해주세요.';

  @override
  String get enterValidAmount => '제출하기 전에 올바른 금액을 입력해주세요.';

  @override
  String get accountNotFound => '계정을 찾을 수 없습니다. 먼저 회원가입해주세요.';

  @override
  String get adminWebOnly => '관리자 기능은 웹에서만 사용할 수 있습니다.';

  @override
  String get loginFailed => '로그인 실패';
}
