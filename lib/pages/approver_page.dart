import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:church_reimbursement/l10n/app_localizations.dart';
import '../models/expense.dart';
import '../models/approval_step.dart'; // _approve/_reject에서 ApprovalStep을 직접 다루기 위해 필요
import '../main.dart';
import 'login_page.dart';

class ApproverPage extends StatefulWidget {
  const ApproverPage({super.key});

  @override
  State<ApproverPage> createState() => _ApproverPageState();
}

class _ApproverPageState extends State<ApproverPage>
    with SingleTickerProviderStateMixin {
  String? _churchId;
  String? _approverUid;
  String? _approverName; // AppBar 제목에 표시할 로그인한 approver 이름
  late TabController _tabController; // 탭 컨트롤러

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this); // 탭 2개
    _loadChurchId();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // 로그인한 유저의 churchId 불러오기
  Future<void> _loadChurchId() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();
    setState(() {
      _churchId = doc['churchId'];
      _approverUid = uid; // 내 uid 저장 — 히스토리 필터용
      _approverName = doc['name']; // AppBar에 표시할 이름
    });
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

  // 영수증 승인
  //
  // 예전엔 승인 버튼 한 번 누르면 무조건 전체 status가 바로 approved가 됐는데,
  // 이제 approvalChain이 여러 단계(tier)일 수 있어서 그렇게 하면 안 됨.
  // 지금 이 사람이 처리하는 건 "이 지출의 여러 승인 단계 중 하나"일 뿐이라,
  // 마지막 단계인지 아닌지에 따라 동작이 갈림:
  //   - 마지막 단계(예: tier 2까지 있는데 지금이 tier 2) → 전체 status를 approved로 확정
  //   - 마지막 단계가 아님(예: tier 2까지 있는데 지금이 tier 1) → currentTier만 다음으로
  //     올려서 다음 담당자(admin_pastor)에게 넘김. 전체 status는 여전히 pending으로 남음
  Future<void> _approve(Expense expense) async {
    // 확인 다이얼로그
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Approve Receipt'),
        content: const Text('Are you sure you want to approve this receipt?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF27500A),
              foregroundColor: Colors.white,
            ),
            child: const Text('OK'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // 승인자 이름 가져오기
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();
    final approverName = userDoc['name'];

    // currentTier는 1부터 시작하는 "몇 번째 단계인지" 숫자라서, approvalChain 리스트의
    // 인덱스로 쓰려면 -1 해줘야 함 (tier 1 → 인덱스 0, tier 2 → 인덱스 1)
    final tierIndex = expense.currentTier - 1;
    // 지금 처리 중인 단계가 approvalChain의 마지막 원소면, 더 넘길 단계가 없다는 뜻
    final isFinalTier = tierIndex >= expense.approvalChain.length - 1;

    // approvalChain 중에서 "지금 처리 중인 단계"만 승인 상태로 바꾸고, 나머지 단계는
    // 그대로 둠(아직 순서가 안 온 단계, 또는 예전에 이미 처리된 단계는 손대면 안 됨)
    final updatedChain = [
      for (var i = 0; i < expense.approvalChain.length; i++)
        if (i == tierIndex)
          ApprovalStep(
            tier: expense.approvalChain[i].tier,
            role: expense.approvalChain[i].role,
            approverUid: expense.approvalChain[i].approverUid,
            status: ApprovalStepStatus.approved,
            actedBy: approverName,
            actedAt: DateTime.now(),
          )
        else
          expense.approvalChain[i],
    ];

    // Firestore 상태 업데이트 + "내가 이 지출을 승인했다"는 개별 기록을
    // approvalActions에 남기는 걸 batch로 묶어서, 둘 다 성공하거나 둘 다 실패하게 함
    // (하나만 성공하면 History에 안 뜨는데 실제로는 승인된 것처럼 상태가 꼬일 수 있음)
    final batch = FirebaseFirestore.instance.batch();

    final expenseRef = FirebaseFirestore.instance
        .collection('churches')
        .doc(_churchId)
        .collection('expenses')
        .doc(expense.id);
    batch.update(expenseRef, {
      'approvalChain': updatedChain.map((s) => s.toMap()).toList(),
      if (isFinalTier)
        ...{
          // 마지막 단계까지 승인됐을 때만 전체 status를 최종 approved로 확정
          'status': 'approved',
          'approvedBy': approverName,
          'approvedByUid': uid,
          'approvedAt': FieldValue.serverTimestamp(),
        }
      else
        ...{
          // 아직 남은 단계가 있으면 다음 담당자한테 넘김 - 전체 status는 pending 그대로 유지
          'currentTier': expense.currentTier + 1,
        },
    });

    // 최종 단계인지 여부와 상관없이, "이 단계를 내가 승인했다"는 기록은 항상 남김
    // - 이게 있어야 중간 단계 담당자도 자기 History 탭에서 본인이 처리한 걸 볼 수 있음
    final actionRef = FirebaseFirestore.instance
        .collection('churches')
        .doc(_churchId)
        .collection('approvalActions')
        .doc();
    batch.set(actionRef, {
      'expenseId': expense.id,
      'approverUid': uid,
      'approverName': approverName,
      'action': 'approved',
      'tier': expense.currentTier,
      'actedAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  // 영수증 반려 (사유 입력)
  //
  // 승인(_approve)과 다르게, 거절은 지금 몇 번째 단계든 상관없이 그 즉시 전체 지출을
  // 반려로 끝냄 (다음 담당자한테 안 넘어감) - 승인 체인 중간에 누구 하나라도 거절하면
  // 그걸로 전체 지출이 반려되는 게 맞는 흐름이라고 판단함.
  Future<void> _reject(Expense expense) async {
    final reasonController = TextEditingController();

    // 반려 사유 입력 다이얼로그
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Receipt'),
        content: TextField(
          controller: reasonController,
          decoration: const InputDecoration(
            labelText: 'Reason for rejection',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Reject'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // 승인자 이름 가져오기
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();
    final approverName = userDoc['name'];
    final reason = reasonController.text.trim();

    // currentTier(1부터 시작)를 approvalChain 배열 인덱스로 변환 (tier 1 → 인덱스 0)
    final tierIndex = expense.currentTier - 1;

    // approvalChain 중 "지금 처리 중인 단계"만 rejected로 표시해서 누가·왜 거절했는지
    // 기록에 남김 - 다른 단계는 그대로 둠
    final updatedChain = [
      for (var i = 0; i < expense.approvalChain.length; i++)
        if (i == tierIndex)
          ApprovalStep(
            tier: expense.approvalChain[i].tier,
            role: expense.approvalChain[i].role,
            approverUid: expense.approvalChain[i].approverUid,
            status: ApprovalStepStatus.rejected,
            actedBy: approverName,
            actedAt: DateTime.now(),
            note: reason,
          )
        else
          expense.approvalChain[i],
    ];

    // Firestore 상태 업데이트 + approvalActions 기록을 batch로 묶어서 원자적으로 처리
    // (_approve와 동일한 이유 - 상태 변경과 History 기록이 따로 놀면 안 됨)
    final batch = FirebaseFirestore.instance.batch();

    final expenseRef = FirebaseFirestore.instance
        .collection('churches')
        .doc(_churchId)
        .collection('expenses')
        .doc(expense.id);
    // 단계와 상관없이 전체 status를 바로 rejected로 확정
    batch.update(expenseRef, {
      'status': 'rejected',
      'rejectReason': reason,
      'approvedBy': approverName,
      'approvedByUid': uid,
      'approvedAt': FieldValue.serverTimestamp(),
      'approvalChain': updatedChain.map((s) => s.toMap()).toList(),
    });

    final actionRef = FirebaseFirestore.instance
        .collection('churches')
        .doc(_churchId)
        .collection('approvalActions')
        .doc();
    batch.set(actionRef, {
      'expenseId': expense.id,
      'approverUid': uid,
      'approverName': approverName,
      'action': 'rejected',
      'tier': expense.currentTier,
      'actedAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  // 영수증 카드 UI (pending용 — 승인/반려 버튼 있음)
  Widget _buildExpenseCard(Expense expense, AppLocalizations l10n) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 영수증 이미지 — 탭하면 크게 보기 + 핀치 줌
            GestureDetector(
              onTap: () => showDialog(
                context: context,
                builder: (_) => Dialog(
                  backgroundColor: Colors.transparent,
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: InteractiveViewer(
                      child: Image.network(
                        expense.imageUrl,
                        errorBuilder: (context, error, stackTrace) => const Padding(
                          padding: EdgeInsets.all(40),
                          child: Icon(Icons.broken_image_outlined, color: Colors.white, size: 64),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  expense.imageUrl,
                  width: 70,
                  height: 90,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    width: 70,
                    height: 90,
                    color: Colors.grey.shade200,
                    child: const Icon(Icons.broken_image_outlined, color: Colors.grey, size: 28),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // 제출자 이름
                      Text(
                        expense.userName ?? 'Unknown',
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w500),
                      ),
                      // 승인/반려 버튼 — 위아래로 배치
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          TextButton.icon(
                            onPressed: () => _approve(expense),
                            icon: const Icon(Icons.check,
                                size: 14, color: Color(0xFF27500A)),
                            label: Text(l10n.approve,
                                style: const TextStyle(
                                    fontSize: 12, color: Color(0xFF27500A))),
                            style: TextButton.styleFrom(
                              backgroundColor: const Color(0xFFEAF3DE),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextButton.icon(
                            onPressed: () => _reject(expense),
                            icon: const Icon(Icons.close,
                                size: 14, color: Color(0xFF501313)),
                            label: Text(l10n.reject,
                                style: const TextStyle(
                                    fontSize: 12, color: Color(0xFF501313))),
                            style: TextButton.styleFrom(
                              backgroundColor: const Color(0xFFFCEBEB),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // 금액
                  if (expense.amount != null)
                    Row(
                      children: [
                        const Icon(Icons.attach_money,
                            size: 14, color: Colors.green),
                        const SizedBox(width: 4),
                        Text('\$${expense.amount!.toStringAsFixed(2)}',
                            style: const TextStyle(fontSize: 13)),
                      ],
                    ),
                  const SizedBox(height: 3),
                  // 설명
                  if (expense.description != null &&
                      expense.description!.isNotEmpty)
                    Row(
                      children: [
                        const Icon(Icons.edit, size: 14, color: Colors.orange),
                        const SizedBox(width: 4),
                        Text(expense.description!,
                            style: const TextStyle(
                                fontSize: 13, color: Colors.grey)),
                      ],
                    ),
                  const SizedBox(height: 3),
                  // 날짜
                  Row(
                    children: [
                      const Icon(Icons.calendar_today,
                          size: 14, color: Colors.red),
                      const SizedBox(width: 4),
                      Text(
                        '${expense.createdAt.year}/${expense.createdAt.month}/${expense.createdAt.day}',
                        style:
                            const TextStyle(fontSize: 13, color: Colors.grey),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 히스토리 카드 UI (승인/반려 버튼 없음, 상태 배지 있음)
  Widget _buildHistoryCard(Expense expense) {
    // 상태별 배지 색상
    final isApproved = expense.status == ExpenseStatus.approved;
    final badgeBg = isApproved ? const Color(0xFFEAF3DE) : const Color(0xFFFCEBEB);
    final badgeText = isApproved ? const Color(0xFF27500A) : const Color(0xFF501313);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 영수증 이미지 — 탭하면 크게 보기
            GestureDetector(
              onTap: () => showDialog(
                context: context,
                builder: (_) => Dialog(
                  backgroundColor: Colors.transparent,
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: InteractiveViewer(
                      child: Image.network(
                        expense.imageUrl,
                        errorBuilder: (context, error, stackTrace) => const Padding(
                          padding: EdgeInsets.all(40),
                          child: Icon(Icons.broken_image_outlined, color: Colors.white, size: 64),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  expense.imageUrl,
                  width: 70,
                  height: 90,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    width: 70,
                    height: 90,
                    color: Colors.grey.shade200,
                    child: const Icon(Icons.broken_image_outlined, color: Colors.grey, size: 28),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // 제출자 이름
                      Text(
                        expense.userName ?? 'Unknown',
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w500),
                      ),
                      // 상태 배지
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: badgeBg,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          isApproved ? 'Approved' : 'Rejected',
                          style: TextStyle(
                              fontSize: 11,
                              color: badgeText,
                              fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // 금액
                  if (expense.amount != null)
                    Row(
                      children: [
                        const Icon(Icons.attach_money,
                            size: 14, color: Colors.green),
                        const SizedBox(width: 4),
                        Text('\$${expense.amount!.toStringAsFixed(2)}',
                            style: const TextStyle(fontSize: 13)),
                      ],
                    ),
                  const SizedBox(height: 3),
                  // 설명
                  if (expense.description != null &&
                      expense.description!.isNotEmpty)
                    Row(
                      children: [
                        const Icon(Icons.edit, size: 14, color: Colors.orange),
                        const SizedBox(width: 4),
                        Text(expense.description!,
                            style: const TextStyle(
                                fontSize: 13, color: Colors.grey)),
                      ],
                    ),
                  const SizedBox(height: 3),
                  // 날짜
                  Row(
                    children: [
                      const Icon(Icons.calendar_today,
                          size: 14, color: Colors.red),
                      const SizedBox(width: 4),
                      Text(
                        '${expense.createdAt.year}/${expense.createdAt.month}/${expense.createdAt.day}',
                        style:
                            const TextStyle(fontSize: 13, color: Colors.grey),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // pending 상태 영수증 목록
  Widget _buildPendingList() {
    final l10n = AppLocalizations.of(context)!;
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('churches')
          .doc(_churchId)
          .collection('expenses')
          .where('status', isEqualTo: 'pending')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData) {
          return Center(child: Text(l10n.reviewReceipts));
        }
        // member가 soft-delete(hiddenFromMember)로 철회한 건은 승인 대상에서 제외
        final expenses = snapshot.data!.docs
            .where((d) => (d.data() as Map<String, dynamic>?)?['hiddenFromMember'] != true)
            .map((doc) => Expense.fromFirestore(doc))
            .where((e) => !e.draft) // 웹에서 아직 Submit 안 한 draft는 승인 대상 아님
            // 예전엔 이 교회 approver/admin이면 pending 전체가 다 보였는데, 이제 지출마다
            // "지금 몇 단계(tier)인지"와 "그 단계 담당자가 누구인지"가 정해져 있으므로
            // 로그인한 나(_approverUid)가 지금 단계의 담당자일 때만 보이게 필터링함.
            .where((e) {
              // currentTier(1부터 시작)를 approvalChain 배열 인덱스로 변환
              final tierIndex = e.currentTier - 1;
              // 인덱스가 범위를 벗어나면(데이터 이상) 안전하게 숨김
              if (tierIndex < 0 || tierIndex >= e.approvalChain.length) return false;
              // 담당자가 아직 미배정(부서장/Admin Pastor를 admin이 안 정해서 approverUid가
              // null)이면 아무한테도 안 보임 - admin이 나중에 담당자를 지정하면 그때부터 보임
              return e.approvalChain[tierIndex].approverUid == _approverUid;
            })
            .toList();
        if (expenses.isEmpty) {
          return Center(child: Text(l10n.reviewReceipts));
        }
        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          itemCount: expenses.length,
          itemBuilder: (context, index) =>
              _buildExpenseCard(expenses[index], l10n),
        );
      },
    );
  }

  // 내가 처리한 history 목록
  //
  // 예전엔 expenses 문서의 top-level approvedByUid로 필터링했는데, 그 필드는
  // 승인 체인의 "마지막 단계"를 처리한 사람한테만 기록돼서, 중간 단계 담당자는
  // 자기가 승인했어도 여기 안 떴음(버그). 그래서 이제 _approve/_reject에서
  // 매번 남기는 approvalActions 기록(내가 처리한 것만 독립적으로 쌓인 컬렉션)을
  // 기준으로 조회함 - 몇 번째 단계를 처리했든 무조건 본인 기록이 남음.
  Widget _buildHistoryList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('churches')
          .doc(_churchId)
          .collection('approvalActions')
          .where('approverUid', isEqualTo: _approverUid)
          .snapshots(),
      builder: (context, actionSnapshot) {
        if (actionSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!actionSnapshot.hasData || actionSnapshot.data!.docs.isEmpty) {
          return const Center(
            child: Text('No history yet',
                style: TextStyle(color: Colors.grey)),
          );
        }

        // actedAt 기준 최신순으로 정렬 (Firestore 쿼리에 orderBy를 안 쓴 건, 다른
        // 필드로 where + orderBy를 같이 쓰면 복합 인덱스를 따로 만들어야 해서 그럼)
        final actionDocs = actionSnapshot.data!.docs.toList()
          ..sort((a, b) {
            final aTime = a['actedAt'] as Timestamp?;
            final bTime = b['actedAt'] as Timestamp?;
            if (aTime == null || bTime == null) return 0;
            return bTime.compareTo(aTime);
          });

        // 같은 지출을 두 단계에 걸쳐 내가 처리한 경우(드물지만 한 사람이 두 단계를
        // 겸임하는 경우) 카드가 중복으로 뜨지 않도록 expenseId 기준 중복 제거
        final expenseIds = <String>[];
        for (final doc in actionDocs) {
          final expenseId = doc['expenseId'] as String;
          if (!expenseIds.contains(expenseId)) expenseIds.add(expenseId);
        }

        return FutureBuilder<List<DocumentSnapshot>>(
          future: Future.wait(expenseIds.map(
            (id) => FirebaseFirestore.instance
                .collection('churches')
                .doc(_churchId)
                .collection('expenses')
                .doc(id)
                .get(),
          )),
          builder: (context, expenseSnapshot) {
            if (!expenseSnapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            // member가 soft-delete한 건은 approver 본인 History에서도 제외
            final expenses = expenseSnapshot.data!
                .where((d) =>
                    d.exists &&
                    (d.data() as Map<String, dynamic>?)?['hiddenFromMember'] !=
                        true)
                .map((doc) => Expense.fromFirestore(doc))
                .toList();
            if (expenses.isEmpty) {
              return const Center(
                child: Text('No history yet',
                    style: TextStyle(color: Colors.grey)),
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              itemCount: expenses.length,
              itemBuilder: (context, index) =>
                  _buildHistoryCard(expenses[index]),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    // churchId 로드 전 스피너
    if (_churchId == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.orange.shade50,
      appBar: AppBar(
        // 이름을 아직 못 불러온 로딩 중엔 이름 없는 기본 제목을 보여줌
        title: Text(
          _approverName != null
              ? l10n.approverDashboardWithName(_approverName!)
              : l10n.approverDashboard,
        ),
        backgroundColor: Colors.orange,
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
                MaterialPageRoute(builder: (_) => LoginPage()),
                (route) => false,
              );
            },
          ),
        ],
        // 탭바
        bottom: TabBar(
        controller: _tabController,
        indicatorColor: Colors.black,
        labelColor: Colors.black,
        unselectedLabelColor: Colors.black54,
          tabs: const [
            Tab(text: 'Pending'),
            Tab(text: 'History'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildPendingList(),  // 첫 번째 탭 — pending
          _buildHistoryList(),  // 두 번째 탭 — 내 히스토리
        ],
      ),
    );
  }
}