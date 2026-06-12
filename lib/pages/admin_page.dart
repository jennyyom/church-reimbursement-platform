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
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

        final docs = snapshot.data!.docs;
        final total = docs.length;
        final pending = docs.where((d) => (d['status'] as String?) == 'pending').length;
        final approved = docs.where((d) => (d['status'] as String?) == 'approved').length;
        final totalAmount = docs
            .where((d) => (d['status'] as String?) == 'approved')
            .fold<double>(0, (sum, d) => sum + ((d['amount'] as num?)?.toDouble() ?? 0));

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
                      // status null 안전 처리
                      final status = (doc['status'] as String?) ?? 'pending';
                      final date = (doc['createdAt'] as dynamic)?.toDate();
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
                                Expanded(child: Text(doc['userName'] ?? '-', style: const TextStyle(fontSize: 13))),
                                Expanded(child: Text(doc['description'] ?? '-', style: const TextStyle(fontSize: 13))),
                                Expanded(child: Text('\$${((doc['amount'] as num?)?.toDouble() ?? 0).toStringAsFixed(2)}', style: const TextStyle(fontSize: 13))),
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
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

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
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

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
                        // status null 안전 처리
                        final status = (doc['status'] as String?) ?? 'pending';
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
                                  Expanded(child: Text(doc['userName'] ?? '-', style: const TextStyle(fontSize: 13))),
                                  Expanded(child: Text(doc['description'] ?? '-', style: const TextStyle(fontSize: 13))),
                                  Expanded(child: Text('\$${((doc['amount'] as num?)?.toDouble() ?? 0).toStringAsFixed(2)}', style: const TextStyle(fontSize: 13))),
                                  Expanded(child: Text(doc['approvedBy'] ?? '-', style: const TextStyle(fontSize: 13))),
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
                        : const SizedBox(),
          ),
        ],
      ),
    );
  }
}