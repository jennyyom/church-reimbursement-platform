import 'package:flutter_test/flutter_test.dart';
import 'package:church_reimbursement/utils/approval_chain_builder.dart';

// 기존 테스트(test/approval_chain_builder_test.dart) 연결:
// 기존 5개 케이스는 $500 경계(500.00 -> 2단계, 500.01 -> 3단계), $0, $100,000
// 다루고 있다. 이 파일은 그 경계 주변의 빠진 엣지 케이스를 채운다.
// 실행: flutter test test/approval_chain_edge_test.dart

void main() {
  group('buildApprovalChain - edge cases', () {
    test('499.99 -> 2 steps (just under the boundary)', () {
      final chain = buildApprovalChain(499.99);
      expect(chain.length, 2);
      expect(chain.map((s) => s.role).toList(),
          ['department_head', 'admin_pastor']);
    });

    test('500.005 -> 3 steps (float cents cross the boundary)', () {
      // QA finding: OCR 금액이 소수점 3자리 이상으로 들어오면
      // $500.005가 3단계가 된다. 통화는 센트(2자리) 단위이므로
      // 업로드 플로우에서 금액을 2자리로 반올림한 뒤 체인을 만드는 게 안전하다.
      // 이 테스트는 현재 동작을 고정한 것이지, 의도된 스펙은 아니다.
      final chain = buildApprovalChain(500.005);
      expect(chain.length, 3);
    });

    test('tiers are strictly ascending 1, 2, 3 for over-500 amounts', () {
      final chain = buildApprovalChain(750.00);
      expect(chain.map((s) => s.tier).toList(), [1, 2, 3]);
    });

    test('roles are unique and in order for every amount', () {
      final small = buildApprovalChain(100);
      final large = buildApprovalChain(1000);
      expect(small.map((s) => s.role).toSet().length, small.length);
      expect(large.map((s) => s.role).toSet().length, large.length);
      expect(large.last.role, 'finance_chair');
    });

    test('negative amount currently yields 2 steps (validation gap)', () {
      // QA finding: 음수 금액이 2단계 체인을 그대로 받는다.
      // buildApprovalChain이 막는 게 아니라 업로드 폼에서
      // amount <= 0 제출을 막아야 한다. 이 테스트는 현재 동작을 기록한 것.
      final chain = buildApprovalChain(-50);
      expect(chain.length, 2);
    });

    test('new steps start unassigned and pending', () {
      final chain = buildApprovalChain(600);
      for (final step in chain) {
        expect(step.approverUid, isNull);
        expect(step.status.name, 'pending');
      }
    });
  });
}
