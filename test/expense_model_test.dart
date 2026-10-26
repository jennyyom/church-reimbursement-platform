import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:church_reimbursement/models/approval_step.dart';
import 'package:church_reimbursement/models/expense.dart';

// Expense 생성자 기본값 + toFirestore 직렬화 테스트.
// Firestore 문서(DocumentSnapshot)가 필요 없는 부분만 다룬다.
// fromFirestore 테스트는 fake_cloud_firestore 패키지가 필요하므로 별도 메모 참고.
// 실행: flutter test test/expense_model_test.dart

Expense _sampleExpense() {
  return Expense(
    id: 'exp-1',
    uid: 'user-1',
    churchId: 'church-1',
    imageUrl: 'https://example.com/receipt.jpg',
    storagePath: 'receipts/exp-1.jpg',
    amount: 750.00,
    description: 'Sunday lunch',
    userName: 'Jenny',
    status: ExpenseStatus.pending,
    createdAt: DateTime(2026, 10, 20),
    approvalChain: [
      ApprovalStep(tier: 1, role: 'department_head'),
      ApprovalStep(tier: 2, role: 'admin_pastor'),
      ApprovalStep(tier: 3, role: 'finance_chair'),
    ],
    currentTier: 1,
  );
}

void main() {
  group('Expense constructor defaults', () {
    test('draft defaults to false, chain to empty, tier to 1', () {
      final expense = Expense(
        id: 'exp-2',
        uid: 'user-2',
        churchId: 'church-1',
        imageUrl: 'https://example.com/r.jpg',
        status: ExpenseStatus.pending,
        createdAt: DateTime(2026, 10, 20),
      );
      expect(expense.draft, isFalse);
      expect(expense.approvalChain, isEmpty);
      expect(expense.currentTier, 1);
      expect(expense.amount, isNull);
      expect(expense.description, isNull);
    });
  });

  group('Expense toFirestore', () {
    test('status serializes as its name string', () {
      final map = _sampleExpense().toFirestore();
      expect(map['status'], 'pending');
    });

    test('approvalChain serializes to a list of maps with roles', () {
      final map = _sampleExpense().toFirestore();
      final chain = map['approvalChain'] as List;
      expect(chain.length, 3);
      expect(chain[2]['role'], 'finance_chair');
      expect(chain[0]['status'], 'pending');
    });

    test('currentTier and draft survive serialization', () {
      final map = _sampleExpense().toFirestore();
      expect(map['currentTier'], 1);
      expect(map['draft'], isFalse);
    });

    test('createdAt is a server timestamp sentinel', () {
      final map = _sampleExpense().toFirestore();
      expect(map['createdAt'], isA<FieldValue>());
    });

    test('amount and description pass through unchanged', () {
      final map = _sampleExpense().toFirestore();
      expect(map['amount'], 750.00);
      expect(map['description'], 'Sunday lunch');
    });
  });
}

// NOTE — fromFirestore 테스트를 추가하려면:
// dev_dependencies에 fake_cloud_firestore를 추가한 뒤,
// FakeFirebaseFirestore 인스턴스에 문서를 넣고
// Expense.fromFirestore(doc)로 다음 기본값을 검증한다:
//  - status 필드 없음/알 수 없는 값 -> pending
//  - createdAt 없음 -> 현재 시각 (오차 범위 내)
//  - draft 없음 -> false, approvalChain 없음 -> [], currentTier 없음 -> 1
//  - amount가 int로 저장된 경우 -> double로 변환
