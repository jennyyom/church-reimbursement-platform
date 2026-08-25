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

        final docs = snapshot.data!.docs;
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
                                // role 드롭다운 — Expanded 대신 SizedBox로 assertion 에러 방지
                                SizedBox(
                                  width: 120,
                                  child: DropdownButtonFormField<String>(
                                    value: role,
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
  // Departments 탭 - 부서 추가 다이얼로그
  // "+ Add Department" 버튼을 누르면 이 팝업창이 뜸
  // ============================================
  void _showAddDepartmentDialog() {
    // 팝업 안 입력칸 3개를 위한 컨트롤러
    final codeController = TextEditingController();       // 부서 코드 (예: 306)
    final nameController = TextEditingController();       // 부서 이름 (예: Finance)
    final chairNameController = TextEditingController();  // 부서장 이름

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add Department'),
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
                // 부서장 이름 입력칸
                TextField(
                  controller: chairNameController,
                  decoration: const InputDecoration(labelText: 'Dept Chair Name'),
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
            // 추가 버튼 - Firestore에 저장 후 팝업 닫기
            ElevatedButton(
              onPressed: () async {
                // 코드나 이름이 비어있으면 저장 안 함
                if (codeController.text.isEmpty || nameController.text.isEmpty) return;

                // Firestore의 churches/{churchId}/departments 서브컬렉션에
                // 새 문서를 추가함 (add()는 자동으로 랜덤 ID 생성)
                await FirebaseFirestore.instance
                    .collection('churches')
                    .doc(_churchId)
                    .collection('departments')
                    .add({
                  'code': codeController.text.trim(),
                  'name': nameController.text.trim(),
                  'chairName': chairNameController.text.trim(),
                  'chairUid': '', // 나중에 실제 유저 uid 연결할 자리 (승인 로직용)
                });

                if (context.mounted) Navigator.pop(context); // 저장 후 팝업 닫기
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
                    onPressed: _showAddDepartmentDialog, // 버튼 누르면 위 팝업 함수 실행
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
                          SizedBox(width: 40, child: Text('')), // 삭제 버튼 자리
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
          Expanded(
            child: _selectedMenu == 'overview'
                ? _buildOverview()
                : _selectedMenu == 'users'
                    ? _buildUsers()
                    : _selectedMenu == 'history'
                        ? _buildHistory()
                        : _buildDepartments(),      // ← 'departments'는 여기로 떨어짐
          ),
        ],
      ),
    );
  }
}