import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:church_reimbursement/l10n/app_localizations.dart';
import '../models/expense.dart';
import '../main.dart';
import 'login_page.dart';

class ApproverPage extends StatefulWidget {
  const ApproverPage({super.key});

  @override
  State<ApproverPage> createState() => _ApproverPageState();
}

class _ApproverPageState extends State<ApproverPage> {
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

  // 언어 선택 바텀시트
  void _showLanguagePicker() {
    showModalBottomSheet(
      context: context,
      builder: (_) => Column(
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
    );
  }

  // 영수증 승인
  Future<void> _approve(String expenseId) async {
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

    // Firestore 상태 업데이트
    await FirebaseFirestore.instance
        .collection('churches')
        .doc(_churchId)
        .collection('expenses')
        .doc(expenseId)
        .update({
          'status': 'approved',
          'approvedBy': approverName,
          'approvedAt': FieldValue.serverTimestamp(),
        });
  }

  // 영수증 반려 (사유 입력)
  Future<void> _reject(String expenseId) async {
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

    // Firestore 상태 업데이트
    await FirebaseFirestore.instance
        .collection('churches')
        .doc(_churchId)
        .collection('expenses')
        .doc(expenseId)
        .update({
          'status': 'rejected',
          'rejectReason': reasonController.text.trim(),
          'approvedBy': approverName,
          'approvedAt': FieldValue.serverTimestamp(),
        });
  }

  // 영수증 카드 UI
  Widget _buildExpenseCard(Expense expense, AppLocalizations l10n) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 영수증 이미지
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                expense.imageUrl,
                width: 70,
                height: 90,
                fit: BoxFit.cover,
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
                      // 승인/반려 버튼
                      Row(
                        children: [
                          TextButton.icon(
                            onPressed: () => _approve(expense.id),
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
                          const SizedBox(width: 6),
                          TextButton.icon(
                            onPressed: () => _reject(expense.id),
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

  // pending 상태 영수증 목록
  Widget _buildExpenseList() {
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

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(child: Text(l10n.reviewReceipts));
        }

        final expenses = snapshot.data!.docs
            .map((doc) => Expense.fromFirestore(doc))
            .toList();

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          itemCount: expenses.length,
          itemBuilder: (context, index) =>
              _buildExpenseCard(expenses[index], l10n),
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
        title: Text(l10n.approverDashboard),
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
      ),
      body: _buildExpenseList(),
    );
  }
}