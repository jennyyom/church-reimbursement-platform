import 'package:flutter_test/flutter_test.dart';
import 'package:church_reimbursement/utils/approval_chain_builder.dart';

void main() {
  group('buildApprovalChain', () {
    test('creates 2 steps for amount of 500 or less', () {
      final chain = buildApprovalChain(500);
      expect(chain.length, 2);
      expect(chain[0].role, 'department_head');
      expect(chain[0].tier, 1);
      expect(chain[1].role, 'admin_pastor');
      expect(chain[1].tier, 2);
    });

    test('creates 3 steps (adds finance_chair) for amount over 500', () {
      final chain = buildApprovalChain(500.01);
      expect(chain.length, 3);
      expect(chain[0].role, 'department_head');
      expect(chain[1].role, 'admin_pastor');
      expect(chain[2].role, 'finance_chair');
      expect(chain[2].tier, 3);
    });

    test('boundary: 500.00 -> 2 steps, 500.01 -> 3 steps', () {
      // 경계값: $500.00까지는 2단계, $500.01부터 3단계
      expect(buildApprovalChain(500.00).length, 2);
      expect(buildApprovalChain(500.01).length, 3);
    });

    test('creates 2 steps for zero amount without error', () {
      final chain = buildApprovalChain(0);
      expect(chain.length, 2);
    });

    test('never exceeds 3 steps for large amounts', () {
      final chain = buildApprovalChain(100000);
      expect(chain.length, 3);
    });
  });
}
