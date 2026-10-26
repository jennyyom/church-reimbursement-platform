import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:church_reimbursement/models/approval_step.dart';

// ApprovalStep toMap/fromMap 왕복 테스트.
// Firestore 문서가 없어도 돌릴 수 있다 (Timestamp는 값 객체라 초기화 불필요).
// 실행: flutter test test/approval_step_model_test.dart

void main() {
  group('ApprovalStep toMap/fromMap', () {
    test('round trip preserves every field', () {
      final actedAt = DateTime(2026, 10, 20, 15, 30);
      final step = ApprovalStep(
        tier: 2,
        role: 'admin_pastor',
        approverUid: 'uid-123',
        status: ApprovalStepStatus.approved,
        actedBy: 'Pastor Kim',
        actedAt: actedAt,
        note: 'ok',
      );

      final restored = ApprovalStep.fromMap(step.toMap());

      expect(restored.tier, 2);
      expect(restored.role, 'admin_pastor');
      expect(restored.approverUid, 'uid-123');
      expect(restored.status, ApprovalStepStatus.approved);
      expect(restored.actedBy, 'Pastor Kim');
      expect(restored.actedAt, actedAt);
      expect(restored.note, 'ok');
    });

    test('unknown status string falls back to pending', () {
      final step = ApprovalStep.fromMap({
        'tier': 1,
        'role': 'department_head',
        'status': 'something_new',
      });
      expect(step.status, ApprovalStepStatus.pending);
    });

    test('missing status falls back to pending', () {
      final step = ApprovalStep.fromMap({
        'tier': 1,
        'role': 'department_head',
      });
      expect(step.status, ApprovalStepStatus.pending);
    });

    test('defaults: pending, unassigned, no actedAt', () {
      final step = ApprovalStep(tier: 1, role: 'department_head');
      expect(step.status, ApprovalStepStatus.pending);
      expect(step.approverUid, isNull);
      expect(step.actedAt, isNull);
      expect(step.actedBy, isNull);
      expect(step.note, isNull);
    });

    test('toMap writes actedAt as Timestamp and null stays null', () {
      final withDate = ApprovalStep(
        tier: 3,
        role: 'finance_chair',
        actedAt: DateTime(2026, 10, 21),
      );
      expect(withDate.toMap()['actedAt'], isA<Timestamp>());

      final withoutDate = ApprovalStep(tier: 3, role: 'finance_chair');
      expect(withoutDate.toMap()['actedAt'], isNull);
    });

    test('all four statuses survive a round trip', () {
      for (final status in ApprovalStepStatus.values) {
        final step = ApprovalStep(tier: 1, role: 'x', status: status);
        expect(ApprovalStep.fromMap(step.toMap()).status, status);
      }
    });
  });
}