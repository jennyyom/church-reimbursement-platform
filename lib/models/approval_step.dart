import 'package:cloud_firestore/cloud_firestore.dart';

enum ApprovalStepStatus { pending, approved, rejected, skipped }

class ApprovalStep {
  final int tier;                 // 1, 2 — 몇 번째 단계인지
  final String role;              // 'department_head', 'admin_pastor'
  final String? approverUid;      // 이 단계를 처리할 사람 (아직 미배정이면 null)
  final ApprovalStepStatus status;
  final String? actedBy;          // 실제 승인/거절한 사람 이름
  final DateTime? actedAt;
  final String? note;             // 거절 사유 등

  ApprovalStep({
    required this.tier,
    required this.role,
    this.approverUid,
    this.status = ApprovalStepStatus.pending,
    this.actedBy,
    this.actedAt,
    this.note,
  });

  factory ApprovalStep.fromMap(Map<String, dynamic> map) {
    return ApprovalStep(
      tier: map['tier'],
      role: map['role'],
      approverUid: map['approverUid'],
      status: ApprovalStepStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => ApprovalStepStatus.pending,
      ),
      actedBy: map['actedBy'],
      actedAt: map['actedAt'] != null
          ? (map['actedAt'] as Timestamp).toDate()
          : null,
      note: map['note'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'tier': tier,
      'role': role,
      'approverUid': approverUid,
      'status': status.name,
      'actedBy': actedBy,
      'actedAt': actedAt != null ? Timestamp.fromDate(actedAt!) : null,
      'note': note,
    };
  }
}