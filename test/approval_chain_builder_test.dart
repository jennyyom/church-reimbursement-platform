import 'package:flutter_test/flutter_test.dart';
import 'package:church_reimbursement/utils/approval_chain_builder.dart';

void main() {
  group('buildApprovalChain', () {
    test('500불 이하이면 1단계(department_head)만 생성', () {
      final chain = buildApprovalChain(500);
      expect(chain.length, 1);
      expect(chain[0].role, 'department_head');
    });

    test('500불 초과이면 2단계 생성', () {
      final chain = buildApprovalChain(500.01);
      expect(chain.length, 2);
      expect(chain[0].role, 'department_head');
      expect(chain[1].role, 'admin_pastor');
    });

    test('0원이어도 에러 없이 최소 1단계는 생성', () {
      final chain = buildApprovalChain(0);
      expect(chain.length, 1);
    });
  });
}
