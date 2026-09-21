import 'approval_step.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

enum ExpenseStatus { pending, approved, rejected }

class Expense {
  final String id;
  final String uid;
  final String churchId;
  final String imageUrl;
  final String? storagePath; // OCR용 Storage 파일 경로
  final double? amount;
  final String? description;
  final String? departmentId; // 나중에 부서 기능용, 지금은 null
  // 부서 이름을 화면(예: 홈 화면 "My Receipts")에 보여줄 때 departmentId로 매번
  // departments 문서를 다시 조회하지 않아도 되게, 제출 시점의 이름을 그대로 복사해서
  // 저장해둔 값. chairName/userName처럼 이 코드베이스에서 이미 쓰던 비정규화(denormalize)
  // 패턴을 그대로 따름. 나중에 부서 이름이 바뀌어도 이 값은 제출 당시 이름으로 남음.
  final String? departmentName;
  final String? userName;     // 제출자 이름
  final ExpenseStatus status;
  final DateTime createdAt;
  final String? approvedBy;   // 승인/거절한 사람 이름
  final DateTime? approvedAt; // 승인/거절 날짜
  final String? rejectReason; // 거절 이유
  final bool draft; // true면 아직 확정 제출 전 - approver/admin/본인 목록에 안 보임
  final List<ApprovalStep> approvalChain;
  final int currentTier; 

  Expense({
    required this.id,
    required this.uid,
    required this.churchId,
    required this.imageUrl,
    this.storagePath,
    this.amount,
    this.description,
    this.departmentId,
    this.departmentName,
    this.userName,
    this.approvedBy,   // 추가
    this.approvedAt,   // 추가
    this.rejectReason,
    this.draft = false,
    required this.status,
    required this.createdAt,
    this.approvalChain = const [],   // ← 추가
    this.currentTier = 1,            // ← 추가
  });

  factory Expense.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Expense(
      id: doc.id,
      uid: data['uid'],
      churchId: data['churchId'],
      imageUrl: data['imageUrl'],
      storagePath: data['storagePath'],
      amount: (data['amount'] as num?)?.toDouble(),
      description: data['description'],
      departmentId: data['departmentId'],
      departmentName: data['departmentName'],
      userName: data['userName'],
      rejectReason: data['rejectReason'],
      approvedBy: data['approvedBy'],
      approvedAt: data['approvedAt'] != null
          ? (data['approvedAt'] as Timestamp).toDate()
          : null,
      draft: data['draft'] == true, // 필드 없는 옛날 문서는 전부 정식 제출로 취급
      status: ExpenseStatus.values.firstWhere(
        (e) => e.name == data['status'],
        orElse: () => ExpenseStatus.pending,
      ),
      createdAt: data['createdAt'] != null 
    ? (data['createdAt'] as Timestamp).toDate() 
    : DateTime.now(),
      approvalChain: (data['approvalChain'] as List<dynamic>?)
            ?.map((m) => ApprovalStep.fromMap(m as Map<String, dynamic>))
            .toList() ??
        [],                                          // ← 추가
    currentTier: data['currentTier'] ?? 1,           // ← 추가
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'uid': uid,
      'churchId': churchId,
      'imageUrl': imageUrl,
      'storagePath': storagePath,
      'amount': amount,
      'description': description,
      'departmentId': departmentId,
      'departmentName': departmentName,
      'userName': userName,
      'status': status.name,
      'approvedBy': approvedBy,
      'approvedAt': approvedAt,
      'rejectReason': rejectReason,
      'draft': draft,
      'createdAt': FieldValue.serverTimestamp(),
      'approvalChain': approvalChain.map((s) => s.toMap()).toList(),  // ← 추가
      'currentTier': currentTier,                                     // ← 추가
    };
  }
}