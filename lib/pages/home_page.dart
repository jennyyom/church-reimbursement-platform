import 'package:flutter/material.dart';
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
      _userName = doc['name'] ?? 'Friend';
      _churchId = doc['churchId'];
    });
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
          final expenses = snapshot.hasData
              ? snapshot.data!.docs
                  .map((d) => Expense.fromFirestore(d))
                  .toList()
              : <Expense>[];

          return ListView(
            padding: const EdgeInsets.all(14),
            children: [
              // 인사말
              Padding(
                padding: const EdgeInsets.only(bottom: 4, left: 2),
                child: Text(
                  'Hi, ${_userName ?? ''}! 👋',
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
                        'Tap to upload',
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
                    Text(
                      'My Receipts',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (expenses.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          child: Text(
                            'No receipts yet',
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

                        return Column(
                          children: [
                            Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                // 설명 + 날짜
                                Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      e.description ?? 'Receipt',
                                      style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${e.createdAt.year}/${e.createdAt.month}/${e.createdAt.day}',
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey.shade400),
                                    ),
                                  ],
                                ),
                                // 금액 + 상태 배지
                                Row(
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
                                        // enum.name으로 String 변환
                                        e.status.name[0].toUpperCase() +
                                            e.status.name.substring(1),
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: badgeText,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
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