import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:church_reimbursement/l10n/app_localizations.dart';
import '../models/expense.dart';

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

  // 현재 로그인한 유저의 churchId 가져오기
  Future<void> _loadChurchId() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();
    setState(() => _churchId = doc['churchId']);
  }

  // 영수증 승인
  Future<void> _approve(String expenseId) async {
    await FirebaseFirestore.instance
        .collection('churches')
        .doc(_churchId)
        .collection('expenses')
        .doc(expenseId)
        .update({'status': 'approved'});
  }

  // 영수증 거절
  Future<void> _reject(String expenseId) async {
    await FirebaseFirestore.instance
        .collection('churches')
        .doc(_churchId)
        .collection('expenses')
        .doc(expenseId)
        .update({'status': 'rejected'});
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

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
      ),
      body: StreamBuilder<QuerySnapshot>(
        // pending 영수증만 실시간으로 가져오기
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
            itemCount: expenses.length,
            itemBuilder: (context, index) {
              final expense = expenses[index];
              return Card(
                margin: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    // 영수증 이미지
                    Image.network(
                      expense.imageUrl,
                      height: 200,
                      fit: BoxFit.cover,
                    ),
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          // 승인 버튼
                          ElevatedButton.icon(
                            onPressed: () => _approve(expense.id),
                            icon: const Icon(Icons.check),
                            label: Text(l10n.approve),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                            ),
                          ),
                          // 거절 버튼
                          ElevatedButton.icon(
                            onPressed: () => _reject(expense.id),
                            icon: const Icon(Icons.close),
                            label: Text(l10n.reject),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}