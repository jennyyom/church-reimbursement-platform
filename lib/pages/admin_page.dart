import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'login_page.dart';
import '../utils/csv_download.dart';

class AdminPage extends StatefulWidget {
  const AdminPage({super.key});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  // 현재 선택된 메뉴 (overview, users, history)
  String _selectedMenu = 'overview';
  String? _churchId;

  @override
  void initState() {
    super.initState();
    _loadChurchId();
  }

  // 로그인한 유저의 churchId 불러오기
  Future<void> _loadChurchId() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();
    setState(() => _churchId = doc['churchId']);
  }

  // 로그아웃
  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
  }

  // CSV 내보내기
  Future<void> _exportCsv() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('churches')
        .doc(_churchId)
        .collection('expenses')
        .get();

    final rows = <String>['Name,Description,Amount,Status,Date,Approved By'];

    for (final doc in snapshot.docs) {
      final data = doc.data();
      final date = (data['createdAt'] as dynamic)?.toDate();
      final dateStr = date != null ? '${date.year}/${date.month}/${date.day}' : '-';
      rows.add(
        '${data['userName'] ?? '-'},'
        '${data['description'] ?? '-'},'
        '${data['amount'] ?? 0},'
        '${data['status'] ?? '-'},'
        '$dateStr,'
        '${data['approvedBy'] ?? '-'}',
      );
    }

    final csv = rows.join('\n');
    await downloadCsv(csv, 'expenses.csv');   //수정
  }

  // 지출 건 삭제 확인 팝업 - admin은 상태 상관없이 삭제 가능
  Future<void> _confirmDeleteExpense(String expenseId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this receipt?'),
        content: const Text('This can\'t be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
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
        .delete();
  }

  // 사이드바 메뉴 아이템
  Widget _buildMenuItem({
    required String id,
    required IconData icon,
    required String label,
  }) {
    final isSelected = _selectedMenu == id;
    return InkWell(
      onTap: () => setState(() => _selectedMenu = id),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        color: isSelected ? Colors.white.withOpacity(0.15) : Colors.transparent,
        child: Row(
          children: [
            Icon(icon, size: 18, color: isSelected ? Colors.white : Colors.white60),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: isSelected ? Colors.white : Colors.white60,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // StreamBuilder 공통 로딩/에러 처리
  // 에러면 에러 메시지, 아직 데이터 없으면 스피너, 정상이면 null 반환
  Widget? _streamStatus(AsyncSnapshot<QuerySnapshot> snapshot) {
    if (snapshot.hasError) {
      return Center(
        child: Text(
          'Failed to load data: ${snapshot.error}',
          style: const TextStyle(color: Colors.red),
          textAlign: TextAlign.center,
        ),
      );
    }
    if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
    return null;
  }

  // Overview — 통계 4개 + 전체 내역
  Widget _buildOverview() {
    if (_churchId == null) return const Center(child: CircularProgressIndicator());
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('churches')
          .doc(_churchId)
          .collection('expenses')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        final statusWidget = _streamStatus(snapshot);
        if (statusWidget != null) return statusWidget;

        // member가 지운(hiddenFromMember) 건은 상태 상관없이 Overview에서 제외.
        // rejected/approved 기록은 History 탭이 항상 그대로 보존하고 있어서 여기선 중복 유지 안 함
        final docs = snapshot.data!.docs.where((d) {
          final data = d.data() as Map<String, dynamic>? ?? {};
          return data['hiddenFromMember'] != true;
        }).toList();
        final total = docs.length;
        final pending = docs.where((d) {
          final data = d.data() as Map<String, dynamic>? ?? {};
          return (data['status'] as String?) == 'pending';
        }).length;
        final approved = docs.where((d) {
          final data = d.data() as Map<String, dynamic>? ?? {};
          return (data['status'] as String?) == 'approved';
        }).length;
        final totalAmount = docs.where((d) {
          final data = d.data() as Map<String, dynamic>? ?? {};
          return (data['status'] as String?) == 'approved';
        }).fold<double>(0, (sum, d) {
          final data = d.data() as Map<String, dynamic>? ?? {};
          return sum + ((data['amount'] as num?)?.toDouble() ?? 0);
        });

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Overview', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
              const SizedBox(height: 20),
              // 통계 카드 4개
              Row(
                children: [
                  _buildStatCard('Total Receipts', '$total', Colors.red.shade800),
                  const SizedBox(width: 12),
                  _buildStatCard('Pending', '$pending', Colors.orange.shade800),
                  const SizedBox(width: 12),
                  _buildStatCard('Approved', '$approved', const Color(0xFF27500A)),
                  const SizedBox(width: 12),
                  _buildStatCard('Total Approved', '\$${totalAmount.toStringAsFixed(2)}', Colors.indigo),
                ],
              ),
              const SizedBox(height: 24),
              // 영수증 테이블
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('Recent Receipts', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                    ),
                    const Divider(height: 1),
                    // 헤더
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      child: Row(
                        children: const [
                          Expanded(child: Text('Name', style: TextStyle(fontSize: 12, color: Colors.grey))),
                          Expanded(child: Text('Description', style: TextStyle(fontSize: 12, color: Colors.grey))),
                          Expanded(child: Text('Amount', style: TextStyle(fontSize: 12, color: Colors.grey))),
                          Expanded(child: Text('Date', style: TextStyle(fontSize: 12, color: Colors.grey))),
                          Expanded(child: Text('Status', style: TextStyle(fontSize: 12, color: Colors.grey))),
                          SizedBox(width: 40, child: Text('')), // 삭제 버튼 자리
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    // 데이터 rows
                    ...docs.map((doc) {
                      final data = doc.data() as Map<String, dynamic>? ?? {};
                      // status null 안전 처리
                      final status = (data['status'] as String?) ?? 'pending';
                      final date = (data['createdAt'] as dynamic)?.toDate();
                      Color badgeBg;
                      Color badgeText;
                      if (status == 'approved') {
                        badgeBg = const Color(0xFFEAF3DE);
                        badgeText = const Color(0xFF27500A);
                      } else if (status == 'rejected') {
                        badgeBg = const Color(0xFFFCEBEB);
                        badgeText = const Color(0xFF501313);
                      } else {
                        badgeBg = const Color(0xFFFAEEDA);
                        badgeText = const Color(0xFF633806);
                      }
                      return Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            child: Row(
                              children: [
                                Expanded(child: Text(data['userName'] ?? '-', style: const TextStyle(fontSize: 13))),
                                Expanded(child: Text(data['description'] ?? '-', style: const TextStyle(fontSize: 13))),
                                Expanded(child: Text('\$${((data['amount'] as num?)?.toDouble() ?? 0).toStringAsFixed(2)}', style: const TextStyle(fontSize: 13))),
                                Expanded(child: Text(date != null ? '${date.year}/${date.month}/${date.day}' : '-', style: const TextStyle(fontSize: 13))),
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(color: badgeBg, borderRadius: BorderRadius.circular(4)),
                                    child: Text(
                                      status[0].toUpperCase() + status.substring(1),
                                      style: TextStyle(fontSize: 11, color: badgeText, fontWeight: FontWeight.w500),
                                    ),
                                  ),
                                ),
                                // approved 건은 삭제 버튼 자체를 안 보여줌 (지급 완료 기록은 영구 보존)
                                SizedBox(
                                  width: 40,
                                  child: status == 'approved'
                                      ? null
                                      : IconButton(
                                          icon: const Icon(Icons.delete_outline, size: 18, color: Colors.grey),
                                          onPressed: () => _confirmDeleteExpense(doc.id),
                                        ),
                                ),
                              ],
                            ),
                          ),
                          const Divider(height: 1),
                        ],
                      );
                    }),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // 통계 카드
  Widget _buildStatCard(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border(left: BorderSide(color: color, width: 4)),
          boxShadow: [BoxShadow(color: Colors.grey.shade100, blurRadius: 4, offset: const Offset(0, 2))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            const SizedBox(height: 6),
            Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: color)),
          ],
        ),
      ),
    );
  }

  // 유저 관리 — 역할 변경 드롭다운
  Widget _buildUsers() {
    if (_churchId == null) return const Center(child: CircularProgressIndicator());

    // 부서 목록을 먼저 구독 (Department 드롭다운 옵션용)
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('churches')
          .doc(_churchId)
          .collection('departments')
          .snapshots(),
      builder: (context, deptSnapshot) {
        final deptStatus = _streamStatus(deptSnapshot);
        if (deptStatus != null) return deptStatus;

        final departments = deptSnapshot.data!.docs;
        final deptNameById = {
          for (final doc in departments)
            doc.id: (doc.data() as Map<String, dynamic>?)?['name'] as String? ?? '-',
        };

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .where('churchId', isEqualTo: _churchId)
              .snapshots(),
          builder: (context, snapshot) {
        final statusWidget = _streamStatus(snapshot);
        if (statusWidget != null) return statusWidget;

        final users = snapshot.data!.docs;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Manage Users', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
              const SizedBox(height: 20),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  children: [
                    // 헤더
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        children: const [
                          Expanded(child: Text('Name', style: TextStyle(fontSize: 12, color: Colors.grey))),
                          Expanded(child: Text('Email', style: TextStyle(fontSize: 12, color: Colors.grey))),
                          SizedBox(width: 200, child: Text('Department', style: TextStyle(fontSize: 12, color: Colors.grey))),
                          SizedBox(width: 24),
                          SizedBox(width: 120, child: Text('Role', style: TextStyle(fontSize: 12, color: Colors.grey))),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    // 유저 목록
                    ...users.map((doc) {
                      // role/name/email 없는 문서 안전 처리
                      final data = doc.data() as Map<String, dynamic>? ?? {};
                      final role = data['role'] as String? ?? 'member';
                      final name = data['name'] as String? ?? '?';
                      final email = data['email'] as String? ?? '-';
                      // departmentId가 없거나 이미 삭제된 부서를 가리키면 미배정으로 취급
                      final rawDeptId = data['departmentId'] as String?;
                      final departmentId = deptNameById.containsKey(rawDeptId) ? rawDeptId : null;
                      return Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            child: Row(
                              children: [
                                // 이름 + 아바타
                                Expanded(
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 16,
                                        backgroundColor: Colors.red.shade50,
                                        child: Text(
                                          name[0].toUpperCase(),
                                          style: TextStyle(fontSize: 13, color: Colors.red.shade800, fontWeight: FontWeight.w600),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Text(name, style: const TextStyle(fontSize: 13)),
                                    ],
                                  ),
                                ),
                                Expanded(child: Text(email, style: const TextStyle(fontSize: 13))),
                                // department 드롭다운 - 기본값 없음(Unassigned), admin이 직접 배정
                                SizedBox(
                                  width: 200,
                                  child: DropdownButtonFormField<String?>(
                                    value: departmentId,
                                    isExpanded: true, // 긴 부서명이 넘칠 때 줄바꿈 대신 잘라서 표시
                                    decoration: const InputDecoration(
                                      border: InputBorder.none,
                                      contentPadding: EdgeInsets.zero,
                                      isDense: true,
                                    ),
                                    items: [
                                      const DropdownMenuItem<String?>(
                                        value: null,
                                        child: Text('Unassigned', style: TextStyle(fontSize: 13, color: Colors.grey)),
                                      ),
                                      ...departments.map((deptDoc) {
                                        final deptData = deptDoc.data() as Map<String, dynamic>? ?? {};
                                        final deptCode = deptData['code'] as String? ?? '-';
                                        final deptName = deptData['name'] as String? ?? '-';
                                        return DropdownMenuItem<String?>(
                                          value: deptDoc.id,
                                          child: Text(
                                            '$deptCode · $deptName',
                                            style: const TextStyle(fontSize: 13),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        );
                                      }),
                                    ],
                                    onChanged: (newDeptId) async {
                                      await FirebaseFirestore.instance
                                          .collection('users')
                                          .doc(doc.id)
                                          .update({'departmentId': newDeptId});
                                    },
                                  ),
                                ),
                                const SizedBox(width: 24),
                                // role 드롭다운 — Expanded 대신 SizedBox로 assertion 에러 방지
                                SizedBox(
                                  width: 120,
                                  child: DropdownButtonFormField<String>(
                                    value: role,
                                    isExpanded: true,
                                    decoration: const InputDecoration(
                                      border: InputBorder.none,
                                      contentPadding: EdgeInsets.zero,
                                      isDense: true,
                                    ),
                                    items: const [
                                      DropdownMenuItem(value: 'member', child: Text('Member', style: TextStyle(fontSize: 13))),
                                      DropdownMenuItem(value: 'approver', child: Text('Approver', style: TextStyle(fontSize: 13))),
                                      DropdownMenuItem(value: 'admin', child: Text('Admin', style: TextStyle(fontSize: 13))),
                                    ],
                                    onChanged: (newRole) async {
                                      if (newRole == null) return;
                                      await FirebaseFirestore.instance
                                          .collection('users')
                                          .doc(doc.id)
                                          .update({'role': newRole});
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Divider(height: 1),
                        ],
                      );
                    }),
                  ],
                ),
              ),
            ],
          ),
        );
          },
        );
      },
    );
  }

  // 히스토리 — Approved/Rejected 전체 내역
  Widget _buildHistory() {
    if (_churchId == null) return const Center(child: CircularProgressIndicator());
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('churches')
          .doc(_churchId)
          .collection('expenses')
          .where('status', whereIn: ['approved', 'rejected'])
          .snapshots(),
      builder: (context, snapshot) {
        final statusWidget = _streamStatus(snapshot);
        if (statusWidget != null) return statusWidget;

        final docs = snapshot.data!.docs;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 제목 + Export 버튼
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('History', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
                  ElevatedButton.icon(
                    onPressed: _exportCsv,
                    icon: const Icon(Icons.download, size: 16),
                    label: const Text('Export CSV'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFB71C1C),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  children: [
                    // 헤더
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        children: const [
                          Expanded(child: Text('Name', style: TextStyle(fontSize: 12, color: Colors.grey))),
                          Expanded(child: Text('Description', style: TextStyle(fontSize: 12, color: Colors.grey))),
                          Expanded(child: Text('Amount', style: TextStyle(fontSize: 12, color: Colors.grey))),
                          Expanded(child: Text('Approved By', style: TextStyle(fontSize: 12, color: Colors.grey))),
                          Expanded(child: Text('Status', style: TextStyle(fontSize: 12, color: Colors.grey))),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    if (docs.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(child: Text('No history yet', style: TextStyle(color: Colors.grey))),
                      )
                    else
                      ...docs.map((doc) {
                        final data = doc.data() as Map<String, dynamic>? ?? {};      // ← 여기 새로 추가
                        // status null 안전 처리
                        final status = data['status'] as String? ?? 'pending';
                        Color badgeBg;
                        Color badgeText;
                        if (status == 'approved') {
                          badgeBg = const Color(0xFFEAF3DE);
                          badgeText = const Color(0xFF27500A);
                        } else {
                          badgeBg = const Color(0xFFFCEBEB);
                          badgeText = const Color(0xFF501313);
                        }
                        return Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              child: Row(
                                children: [
                                  Expanded(child: Text(data['userName'] ?? '-', style: const TextStyle(fontSize: 13))),
                                  Expanded(child: Text(data['description'] ?? '-', style: const TextStyle(fontSize: 13))),
                                  Expanded(child: Text('\$${((data['amount'] as num?)?.toDouble() ?? 0).toStringAsFixed(2)}', style: const TextStyle(fontSize: 13))),
                                  Expanded(child: Text(data['approvedBy'] ?? '-', style: const TextStyle(fontSize: 13))),
                                  Expanded(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(color: badgeBg, borderRadius: BorderRadius.circular(4)),
                                      child: Text(
                                        status[0].toUpperCase() + status.substring(1),
                                        style: TextStyle(fontSize: 11, color: badgeText, fontWeight: FontWeight.w500),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Divider(height: 1),
                          ],
                        );
                      }),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

// ============================================
  // Departments 탭 - 부서 추가/수정 다이얼로그
  // existing이 없으면 추가, 있으면 그 문서를 수정 (문서 ID를 유지해야
  // Activity Codes의 restrictedTo 참조가 안 끊어짐)
  // ============================================
  void _showDepartmentDialog({DocumentSnapshot? existing}) {
    final existingData = existing?.data() as Map<String, dynamic>? ?? {};
    final codeController = TextEditingController(text: existingData['code'] as String? ?? '');
    final nameController = TextEditingController(text: existingData['name'] as String? ?? '');
    // 부서장 uid - 처음엔 기존 값으로, 없으면 미배정
    String? selectedChairUid = existingData['chairUid'] as String?;
    if (selectedChairUid != null && selectedChairUid.isEmpty) selectedChairUid = null;

    showDialog(
      context: context,
      builder: (context) {
        // 부서장 후보 목록 - 이 교회 유저 전체를 한 번만 불러옴
        return FutureBuilder<QuerySnapshot>(
          future: FirebaseFirestore.instance
              .collection('users')
              .where('churchId', isEqualTo: _churchId)
              .get(),
          builder: (context, userSnapshot) {
            if (!userSnapshot.hasData) {
              return const AlertDialog(
                content: SizedBox(height: 80, child: Center(child: CircularProgressIndicator())),
              );
            }

            final users = userSnapshot.data!.docs;
            final userNameById = {
              for (final u in users) u.id: (u.data() as Map<String, dynamic>?)?['name'] as String? ?? '?',
            };
            // 선택된 chairUid가 더 이상 존재하지 않는 유저면(탈퇴 등) 선택 해제
            if (selectedChairUid != null && !userNameById.containsKey(selectedChairUid)) {
              selectedChairUid = null;
            }

            return StatefulBuilder(
              builder: (context, setDialogState) {
                return AlertDialog(
                  title: Text(existing == null ? 'Add Department' : 'Edit Department'),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // 부서 코드 입력칸
                        TextField(
                          controller: codeController,
                          decoration: const InputDecoration(labelText: 'Dept Code (e.g. 306)'),
                        ),
                        const SizedBox(height: 12),
                        // 부서 이름 입력칸
                        TextField(
                          controller: nameController,
                          decoration: const InputDecoration(labelText: 'Dept Name (e.g. Finance)'),
                        ),
                        const SizedBox(height: 12),
                        // 부서장 선택 - 자유 텍스트 대신 실제 유저 중에서 고름
                        DropdownButtonFormField<String?>(
                          value: selectedChairUid,
                          isExpanded: true,
                          decoration: const InputDecoration(labelText: 'Dept Chair'),
                          items: [
                            const DropdownMenuItem<String?>(
                              value: null,
                              child: Text('Unassigned', style: TextStyle(color: Colors.grey)),
                            ),
                            ...users.map((userDoc) {
                              final userData = userDoc.data() as Map<String, dynamic>? ?? {};
                              final userName = userData['name'] as String? ?? '?';
                              final userRole = userData['role'] as String? ?? 'member';
                              return DropdownMenuItem<String?>(
                                value: userDoc.id,
                                child: Text('$userName ($userRole)', overflow: TextOverflow.ellipsis),
                              );
                            }),
                          ],
                          onChanged: (newChairUid) {
                            setDialogState(() => selectedChairUid = newChairUid);
                          },
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    // 취소 버튼 - 그냥 팝업 닫기
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    // 저장 버튼 - Firestore에 추가/수정 후 팝업 닫기
                    ElevatedButton(
                      onPressed: () async {
                        // 코드나 이름이 비어있으면 저장 안 함
                        if (codeController.text.isEmpty || nameController.text.isEmpty) return;

                        final data = {
                          'code': codeController.text.trim(),
                          'name': nameController.text.trim(),
                          'chairUid': selectedChairUid ?? '',
                          // chairName은 선택된 유저 이름을 그대로 복사(denormalize) -
                          // 목록 렌더링할 때 유저를 다시 안 불러와도 되게
                          'chairName': selectedChairUid != null ? (userNameById[selectedChairUid] ?? '') : '',
                        };

                        final deptsRef = FirebaseFirestore.instance
                            .collection('churches')
                            .doc(_churchId)
                            .collection('departments');

                        if (existing == null) {
                          await deptsRef.add(data);
                        } else {
                          await deptsRef.doc(existing.id).update(data);
                        }

                        if (context.mounted) Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFB71C1C),
                        foregroundColor: Colors.white,
                      ),
                      child: Text(existing == null ? 'Add' : 'Save'),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  // ============================================
  // Departments 탭 - 부서 목록 화면
  // 사이드바에서 "Departments" 클릭하면 이 화면이 보임
  // ============================================
  Widget _buildDepartments() {
    // churchId가 아직 로딩 안 됐으면 로딩 스피너만 보여줌
    if (_churchId == null) return const Center(child: CircularProgressIndicator());

    // StreamBuilder = Firestore 데이터를 실시간으로 계속 지켜보다가
    // 데이터가 바뀌면(추가/삭제) 화면을 자동으로 다시 그려줌
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('churches')
          .doc(_churchId)
          .collection('departments')   // 이 교회의 부서 목록만 가져옴
          .snapshots(),
      builder: (context, snapshot) {
        // 에러(예: 권한 부족) 또는 로딩 상태 처리
        final statusWidget = _streamStatus(snapshot);
        if (statusWidget != null) return statusWidget;

        final depts = snapshot.data!.docs; // 부서 문서들 전체 리스트

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 제목 + "+ Add Department" 버튼을 한 줄에 양 끝 정렬
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Departments', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
                  ElevatedButton.icon(
                    onPressed: () => _showDepartmentDialog(), // 버튼 누르면 위 팝업 함수 실행 (추가 모드)
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Add Department'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFB71C1C),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // 부서 목록을 담을 흰색 카드
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  children: [
                    // 테이블 헤더 (컬럼 이름)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        children: const [
                          SizedBox(width: 80, child: Text('Code', style: TextStyle(fontSize: 12, color: Colors.grey))),
                          Expanded(child: Text('Name', style: TextStyle(fontSize: 12, color: Colors.grey))),
                          Expanded(child: Text('Dept Chair', style: TextStyle(fontSize: 12, color: Colors.grey))),
                          SizedBox(width: 76, child: Text('')), // 수정/삭제 버튼 자리
                        ],
                      ),
                    ),
                    const Divider(height: 1),

                    // 부서가 하나도 없으면 안내 문구
                    if (depts.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(child: Text('No departments yet', style: TextStyle(color: Colors.grey))),
                      )
                    else
                      // 부서 문서 하나씩 반복해서 한 줄씩 그림
                      ...depts.map((doc) {
                        final data = doc.data() as Map<String, dynamic>? ?? {};
                        final code = data['code'] as String? ?? '-';
                        final name = data['name'] as String? ?? '-';
                        final chairName = data['chairName'] as String? ?? '-';
                        return Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              child: Row(
                                children: [
                                  SizedBox(width: 80, child: Text(code, style: const TextStyle(fontSize: 13))),
                                  Expanded(child: Text(name, style: const TextStyle(fontSize: 13))),
                                  Expanded(child: Text(chairName, style: const TextStyle(fontSize: 13))),
                                  // 수정 버튼 - 기존 값 채워진 다이얼로그 열기
                                  SizedBox(
                                    width: 36,
                                    child: IconButton(
                                      icon: const Icon(Icons.edit_outlined, size: 18, color: Colors.grey),
                                      onPressed: () => _showDepartmentDialog(existing: doc),
                                    ),
                                  ),
                                  // 삭제 버튼 - 누르면 Firestore에서 이 문서 삭제
                                  SizedBox(
                                    width: 40,
                                    child: IconButton(
                                      icon: const Icon(Icons.delete_outline, size: 18, color: Colors.grey),
                                      onPressed: () async {
                                        await FirebaseFirestore.instance
                                            .collection('churches')
                                            .doc(_churchId)
                                            .collection('departments')
                                            .doc(doc.id)
                                            .delete();
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Divider(height: 1),
                          ],
                        );
                      }),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ============================================
  // Activity Codes 탭 - 코드 추가 다이얼로그
  // 모든 부서가 공용으로 쓰는 지출 항목 코드 (예: 10 Meal & Food)
  // 특정 코드(91 Utilities 등)는 지정된 부서만 쓰도록 제한 가능
  // ============================================
  void _showAddActivityCodeDialog(List<QueryDocumentSnapshot> departments) {
    final codeController = TextEditingController();   // 코드 (예: 10)
    final nameController = TextEditingController();   // 이름 (예: Meal & Food)
    final selectedDeptIds = <String>{};                // 비어있으면 전체 부서 허용

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Add Activity Code'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: codeController,
                      decoration: const InputDecoration(labelText: 'Code (e.g. 10)'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: 'Name (e.g. Meal & Food)'),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Restrict to specific departments (leave all unchecked to allow every department)',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    // 부서 체크박스 목록 - 체크된 부서만 이 코드를 쓸 수 있음
                    ...departments.map((doc) {
                      final data = doc.data() as Map<String, dynamic>? ?? {};
                      final deptCode = data['code'] as String? ?? '-';
                      final deptName = data['name'] as String? ?? '-';
                      return CheckboxListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        title: Text('$deptCode · $deptName', style: const TextStyle(fontSize: 13)),
                        value: selectedDeptIds.contains(doc.id),
                        onChanged: (checked) {
                          setDialogState(() {
                            if (checked == true) {
                              selectedDeptIds.add(doc.id);
                            } else {
                              selectedDeptIds.remove(doc.id);
                            }
                          });
                        },
                      );
                    }),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (codeController.text.isEmpty || nameController.text.isEmpty) return;

                    await FirebaseFirestore.instance
                        .collection('churches')
                        .doc(_churchId)
                        .collection('activityCodes')
                        .add({
                      'code': codeController.text.trim(),
                      'name': nameController.text.trim(),
                      'restrictedTo': selectedDeptIds.toList(), // 부서 문서 ID 목록, 빈 배열 = 전체 허용
                    });

                    if (context.mounted) Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFB71C1C),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Add'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ============================================
  // Activity Codes 탭 - 코드 목록 화면
  // ============================================
  Widget _buildActivityCodes() {
    if (_churchId == null) return const Center(child: CircularProgressIndicator());

    // 부서 목록을 먼저 구독 (제한 대상 부서 이름 표시 + 다이얼로그 체크박스용)
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('churches')
          .doc(_churchId)
          .collection('departments')
          .snapshots(),
      builder: (context, deptSnapshot) {
        final deptStatus = _streamStatus(deptSnapshot);
        if (deptStatus != null) return deptStatus;

        final departments = deptSnapshot.data!.docs;
        final deptNameById = {
          for (final doc in departments)
            doc.id: (doc.data() as Map<String, dynamic>?)?['name'] as String? ?? '-',
        };

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('churches')
              .doc(_churchId)
              .collection('activityCodes')
              .orderBy('code')
              .snapshots(),
          builder: (context, codeSnapshot) {
            final codeStatus = _streamStatus(codeSnapshot);
            if (codeStatus != null) return codeStatus;

            final codes = codeSnapshot.data!.docs;

            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Activity Codes', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
                      ElevatedButton.icon(
                        onPressed: () => _showAddActivityCodeDialog(departments),
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Add Activity Code'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFB71C1C),
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: Row(
                            children: const [
                              SizedBox(width: 60, child: Text('Code', style: TextStyle(fontSize: 12, color: Colors.grey))),
                              Expanded(child: Text('Name', style: TextStyle(fontSize: 12, color: Colors.grey))),
                              Expanded(flex: 2, child: Text('Restricted To', style: TextStyle(fontSize: 12, color: Colors.grey))),
                              SizedBox(width: 40, child: Text('')),
                            ],
                          ),
                        ),
                        const Divider(height: 1),

                        if (codes.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(24),
                            child: Center(child: Text('No activity codes yet', style: TextStyle(color: Colors.grey))),
                          )
                        else
                          ...codes.map((doc) {
                            final data = doc.data() as Map<String, dynamic>? ?? {};
                            final code = data['code'] as String? ?? '-';
                            final name = data['name'] as String? ?? '-';
                            final restrictedTo = (data['restrictedTo'] as List<dynamic>?)?.cast<String>() ?? [];
                            final restrictedLabel = restrictedTo.isEmpty
                                ? 'All departments'
                                : restrictedTo.map((id) => deptNameById[id] ?? '?').join(', ');
                            return Column(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                  child: Row(
                                    children: [
                                      SizedBox(width: 60, child: Text(code, style: const TextStyle(fontSize: 13))),
                                      Expanded(child: Text(name, style: const TextStyle(fontSize: 13))),
                                      Expanded(
                                        flex: 2,
                                        child: Text(restrictedLabel, style: const TextStyle(fontSize: 13, color: Colors.grey)),
                                      ),
                                      SizedBox(
                                        width: 40,
                                        child: IconButton(
                                          icon: const Icon(Icons.delete_outline, size: 18, color: Colors.grey),
                                          onPressed: () async {
                                            await FirebaseFirestore.instance
                                                .collection('churches')
                                                .doc(_churchId)
                                                .collection('activityCodes')
                                                .doc(doc.id)
                                                .delete();
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Divider(height: 1),
                              ],
                            );
                          }),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // 선택된 메뉴에 맞는 화면 반환
  Widget _buildMainContent() {
    switch (_selectedMenu) {
      case 'users':
        return _buildUsers();
      case 'history':
        return _buildHistory();
      case 'departments':
        return _buildDepartments();
      case 'activityCodes':
        return _buildActivityCodes();
      case 'overview':
      default:
        return _buildOverview();
    }
  }

  @override
  Widget build(BuildContext context) {
    // churchId 로드 전 스피너
    if (_churchId == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.red.shade50,
      body: Row(
        children: [
          // 사이드바
          Container(
            width: 200,
            color: const Color(0xFFB71C1C),
            child: Column(
              children: [
                // 로고 영역
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 40, 16, 20),
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.1))),
                  ),
                  child: Row(
                    children: const [
                      Icon(Icons.church, color: Colors.white, size: 22),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Admin',
                          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                // 메뉴 아이템
                _buildMenuItem(id: 'overview', icon: Icons.dashboard_outlined, label: 'Overview'),
                _buildMenuItem(id: 'users', icon: Icons.people_outline, label: 'Users'),
                _buildMenuItem(id: 'history', icon: Icons.history, label: 'History'),
                _buildMenuItem(id: 'departments', icon: Icons.apartment, label: 'Departments'),
                _buildMenuItem(id: 'activityCodes', icon: Icons.receipt_long, label: 'Activity Codes'),
                const Spacer(),
                // 로그아웃
                Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: InkWell(
                    onTap: _logout,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        children: const [
                          Icon(Icons.logout, size: 18, color: Colors.white60),
                          SizedBox(width: 10),
                          Text('Logout', style: TextStyle(fontSize: 13, color: Colors.white60)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // 메인 콘텐츠
          Expanded(child: _buildMainContent()),
        ],
      ),
    );
  }
}