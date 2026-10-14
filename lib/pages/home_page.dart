import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // 날짜를 앱 언어 순서로 표시(DateFormat)
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'upload_page.dart';
import '../main.dart';
import '../models/expense.dart';
import 'package:church_reimbursement/l10n/app_localizations.dart';
import 'login_page.dart';

class UserHomePage extends StatefulWidget {
  const UserHomePage({super.key});

  @override
  State<UserHomePage> createState() => _UserHomePageState();
}

class _UserHomePageState extends State<UserHomePage> {
  String? _userName;
  String? _churchId;
  String _statusFilter = 'all'; // all / pending / approved / rejected

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  // 로그인한 유저 이름 + churchId 불러오기
  Future<void> _loadUserInfo() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();

    setState(() {
      // 이름이 없으면 빈 문자열로 둠. 예전엔 여기서 'Friend'를 넣었는데, 이 시점엔
      // 앱 언어에 맞는 말(l10n.friendFallback)을 알 수 없어서 인사말을 그릴 때 바꿔 넣음.
      // null(아직 불러오는 중)과 ''(불러왔는데 이름 없음)을 구분하려고 null 대신 ''를 씀.
      _userName = doc['name'] ?? '';
      _churchId = doc['churchId'];
    });
  }

  // 영수증 삭제 확인 팝업 - 확인하면 soft-delete(hiddenFromMember 플래그만 세움,
  // 문서 자체는 admin이 계속 볼 수 있도록 남겨둠)
  Future<void> _confirmDeleteExpense(String expenseId) async {
    // build() 밖의 함수라 build의 l10n 변수를 못 써서 여기서 따로 불러옴
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteReceiptTitle),
        // 예전 문구 "This can't be undone."은 완전히 사라지는 것처럼 읽혀서 바꿈.
        // 실제로는 hiddenFromMember 표시만 붙여서 내 목록과 승인자 목록에서만 빠지고,
        // admin에게는 기록으로 남음.
        content: Text(l10n.deleteReceiptMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.delete, style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await FirebaseFirestore.instance
        .collection('churches')
        .doc(_churchId)
        .collection('expenses')
        .doc(expenseId)
        .update({'hiddenFromMember': true});
  }

  // 언어 선택 바텀시트
void _showLanguagePicker() {
  showModalBottomSheet(
    context: context,
    builder: (_) => SafeArea(
      child: Column(
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
    ),
  );
}

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final uid = FirebaseAuth.instance.currentUser!.uid;

    // churchId 로드 전 스피너
    if (_churchId == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // 본인 영수증만 최신순으로 가져오기
    final expenseStream = FirebaseFirestore.instance
        .collection('churches')
        .doc(_churchId)
        .collection('expenses')
        .where('uid', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .snapshots();

    return Scaffold(
      backgroundColor: Colors.indigo.shade50,
      appBar: AppBar(
        title: Text(l10n.appTitle),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        actions: [
          // 언어 변경
          IconButton(
            icon: const Icon(Icons.language),
            onPressed: _showLanguagePicker,
          ),
          // 로그아웃
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (!context.mounted) return;
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const LoginPage()),
                (route) => false,
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: expenseStream,
        builder: (context, snapshot) {
          // hiddenFromMember(soft-delete)로 표시된 건 목록에서 제외
          // (Firestore != 쿼리는 필드 자체가 없는 문서를 걸러내버려서 클라이언트에서 필터링)
          final expenses = snapshot.hasData
              ? snapshot.data!.docs
                  .where((d) => (d.data() as Map<String, dynamic>?)?['hiddenFromMember'] != true)
                  .map((d) => Expense.fromFirestore(d))
                  .where((e) => !e.draft) // Submit 전 draft는 아직 "내 영수증"이 아님
                  .where((e) => _statusFilter == 'all' || e.status.name == _statusFilter)
                  .toList()
              : <Expense>[];

          return ListView(
            // 안드로이드 제스처 네비게이션 바 등 시스템 하단 영역만큼 여백 추가 - 마지막 항목이 가려지지 않도록
            padding: EdgeInsets.fromLTRB(14, 14, 14, 14 + MediaQuery.of(context).padding.bottom),
            children: [
              // 인사말
              Padding(
                padding: const EdgeInsets.only(bottom: 4, left: 2),
                child: Text(
                  // 불러오는 중(null)엔 예전처럼 이름 자리를 비워둠. 여기서 바로 fallback을 쓰면
                  // "성도님"이 잠깐 보였다가 진짜 이름으로 바뀌어서 어색함.
                  // 불러왔는데 이름이 없을 때('')만 friendFallback(Friend/성도)을 씀.
                  l10n.greeting(_userName == null
                      ? ''
                      : (_userName!.isEmpty ? l10n.friendFallback : _userName!)),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.indigo,
                  ),
                ),
              ),

              // Submit Receipt 큰 카드 — 탭하면 UploadPage로 이동
              GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const UploadPage()),
                ),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.indigo,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.receipt_long,
                            color: Colors.white, size: 28),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        l10n.submitReceipt,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l10n.tapToUpload,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.65),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 내 영수증 목록
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                ),
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          l10n.myReceipts,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        // 상태 필터 - 전체/pending/approved/rejected 중 골라서 보기
                        DropdownButton<String>(
                          value: _statusFilter,
                          isDense: true,
                          underline: const SizedBox.shrink(),
                          style: const TextStyle(fontSize: 12, color: Colors.indigo),
                          // value(all/pending/...)는 필터 비교에 쓰는 값이라 영어 그대로 두고,
                          // 화면에 보이는 글자(child)만 번역함. l10n을 쓰면 const를 못 붙임.
                          items: [
                            DropdownMenuItem(value: 'all', child: Text(l10n.filterAll)),
                            DropdownMenuItem(value: 'pending', child: Text(l10n.pending)),
                            DropdownMenuItem(value: 'approved', child: Text(l10n.approved)),
                            DropdownMenuItem(value: 'rejected', child: Text(l10n.rejected)),
                          ],
                          onChanged: (v) {
                            if (v != null) setState(() => _statusFilter = v);
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (expenses.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          child: Text(
                            l10n.noReceiptsYet,
                            style: TextStyle(
                                fontSize: 13, color: Colors.grey.shade400),
                          ),
                        ),
                      )
                    else
                      ...expenses.asMap().entries.map((entry) {
                        final i = entry.key;
                        final e = entry.value;
                        final isLast = i == expenses.length - 1;

                        // 상태별 배지 색상
                        Color badgeBg;
                        Color badgeText;
                        // enum으로 비교
                        if (e.status == ExpenseStatus.approved) {
                          badgeBg = const Color(0xFFEAF3DE);
                          badgeText = const Color(0xFF27500A);
                        } else if (e.status == ExpenseStatus.rejected) {
                          badgeBg = const Color(0xFFFCEBEB);
                          badgeText = const Color(0xFF501313);
                        } else {
                          badgeBg = const Color(0xFFFAEEDA);
                          badgeText = const Color(0xFF633806);
                        }

                        // 금액 + 상태 배지 (+ 삭제 버튼) - 넓은/좁은 화면 레이아웃 둘 다 오른쪽에
                        // 똑같이 들어가서, 두 번 쓰지 않게 변수로 한 번만 만들어 둠
                        final amountStatus = Row(
                          children: [
                            if (e.amount != null)
                              Text(
                                '\$${e.amount!.toStringAsFixed(2)}',
                                style: const TextStyle(fontSize: 13),
                              ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: badgeBg,
                                borderRadius:
                                    BorderRadius.circular(4),
                              ),
                              child: Text(
                                // 예전엔 enum 이름을 대문자로 바꿔서(pending → Pending) 보여줘서
                                // 언어를 바꿔도 항상 영어로 나왔음. 상태별로 번역된 글자를 고름.
                                switch (e.status) {
                                  ExpenseStatus.pending => l10n.pending,
                                  ExpenseStatus.approved => l10n.approved,
                                  ExpenseStatus.rejected => l10n.rejected,
                                },
                                style: TextStyle(
                                  fontSize: 11,
                                  color: badgeText,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            // 삭제 버튼 - pending/rejected만 (approved는 지급 기록이라 보존)
                            if (e.status == ExpenseStatus.pending ||
                                e.status == ExpenseStatus.rejected) ...[
                              const SizedBox(width: 4),
                              InkWell(
                                onTap: () => _confirmDeleteExpense(e.id),
                                child: Icon(Icons.delete_outline,
                                    size: 18, color: Colors.grey.shade400),
                              ),
                            ],
                          ],
                        );

                        // 날짜 문자열 - 넓은 화면에선 설명 옆에, 좁은 화면에선 두 번째 줄에 씀.
                        // 앱 언어에 맞는 순서로 (영어 10/5/2026, 한국어 2026. 10. 5., 스와힐리어 5/10/2026) -
                        // 미국 교회라 연도 먼저(2026/10/5)는 어색했음. 승인 화면과 같은 형식
                        final dateText = DateFormat.yMd(
                                Localizations.localeOf(context).toString())
                            .format(e.createdAt);

                        // 폰처럼 좁은 화면인지 - 폰은 가로 폭이 보통 360~430, 태블릿/컴퓨터는 600보다 넓음.
                        // 웹/앱(kIsWeb)이 아니라 "화면 너비"로 나누는 이유: 교인들이 폰 브라우저로
                        // 웹사이트에 들어와도 화면이 좁기는 똑같아서, 그때도 좁은 레이아웃이 나와야 함.
                        final isNarrow = MediaQuery.sizeOf(context).width < 600;

                        return Column(
                          children: [
                            isNarrow
                                // 좁은 화면(폰): 가운데에 부서 배지를 둘 자리가 없어서(설명과 금액
                                // 사이 공간이 거의 없음) 두 줄로 나눔.
                                //   1줄: 설명 + 오른쪽에 금액/상태
                                //   2줄: 날짜 · 부서 - 금액/상태 아래까지 화면 전체 폭을 씀
                                // 처음엔 설명과 날짜·부서를 둘 다 금액 왼쪽에 쌓았는데, 금액/상태가
                                // 오른쪽 폭을 차지해서 부서 이름이 조금만 길어도 줄바꿈됐음.
                                // 그래서 날짜·부서 줄을 금액 아래로 내려 전체 폭을 쓰게 함.
                                // 2줄은 연한 남색(indigo.shade300) - 회색보다 잘 보이면서도 설명보다는
                                // 눈에 덜 띄게. 부서가 없는 옛날 지출은 날짜만 나옴.
                                //
                                // 말줄임(...)으로 자르지 않는 이유: 이 목록은 눌러도 상세 화면이 없어서
                                // 잘린 글자를 볼 방법이 없음 - 줄이 늘어나더라도 설명과 부서 이름은
                                // 항상 전부 보여야 함 (길면 다음 줄로 줄바꿈)
                                ? Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.center,
                                        children: [
                                          // Expanded: 설명이 길어도 오른쪽 금액/상태를 밀어내지 않고
                                          // 남은 폭 안에서 줄바꿈되게 함
                                          Expanded(
                                            child: Text(
                                              e.description ?? l10n.receiptFallback,
                                              style: const TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w500),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          amountStatus,
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        e.departmentName == null
                                            ? dateText
                                            : '$dateText · ${e.departmentName}',
                                        style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.indigo.shade300),
                                      ),
                                    ],
                                  )
                                // 넓은 화면(컴퓨터 웹): 기존 한 줄 레이아웃 그대로
                                : Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    // 설명 + 날짜 - 원래 위아래로 두 줄이었는데, 부서 배지처럼
                                    // 한 줄에 나란히 놓으면 더 컴팩트해 보여서 옆으로 붙임
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.baseline,
                                      textBaseline: TextBaseline.alphabetic,
                                      children: [
                                        Text(
                                          e.description ?? l10n.receiptFallback,
                                          style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          dateText,
                                          style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey.shade400),
                                        ),
                                      ],
                                    ),
                                    // 제출한 부서 - 승인 라우팅이 부서 기준으로 도는데, 정작
                                    // 제출한 본인은 어느 부서로 보냈는지 확인할 데가 없어서 추가함.
                                    // 왼쪽(설명/날짜)과 오른쪽(금액/상태) 사이에 항상 비어있던
                                    // 공간을 Expanded+Center로 채워서 배지 형태로 보여줌 -
                                    // 왼쪽 Column에 세 번째 줄로 쌓으면 글씨가 계속 작아지고
                                    // 줄만 늘어나서, 대신 원래 비어있던 가운데 공간을 활용함.
                                    // departmentName이 없으면(옛날 지출 등) 빈 공간 그대로 둠.
                                    Expanded(
                                      child: e.departmentName == null
                                          ? const SizedBox.shrink()
                                          : Center(
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(
                                                    horizontal: 8, vertical: 3),
                                                decoration: BoxDecoration(
                                                  color: Colors.indigo.shade50,
                                                  borderRadius:
                                                      BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  e.departmentName!,
                                                  style: TextStyle(
                                                      fontSize: 11,
                                                      color: Colors.indigo.shade400,
                                                      fontWeight: FontWeight.w500),
                                                ),
                                              ),
                                            ),
                                    ),
                                    // 금액 + 상태 배지 (자기 너비만 차지 - 오른쪽 정렬)
                                    amountStatus,
                                  ],
                                ),
                            // 마지막 아이템 제외 구분선
                            if (!isLast)
                              Divider(
                                height: 16,
                                thickness: 0.5,
                                color: Colors.grey.shade200,
                              ),
                          ],
                        );
                      }),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}