import '../models/approval_step.dart';

// 금액에 따라 승인 체인(누가 몇 단계로 승인하는지)을 만든다.
// 여기서는 각 단계의 tier/role만 정하고, 실제 승인자 uid(approverUid)는
// upload_page.dart의 _resolveApprovalChain이 제출 시점에 채워 넣는다.
//
// 승인 흐름:
//   - $500 이하 : Dept. Chair → Admin. Pastor                 (2단계)
//   - $500 초과 : Dept. Chair → Admin. Pastor → Finance Chair (3단계)
//
// 기준을 '> 500'으로 둔 이유: 금액에 센트가 있으므로 $500.00까지는 2단계,
// $500.01부터는 Finance Chair까지 가야 한다. ($501부터로 하려면 '>= 501'로 바꿀 것)
//
// 모든 금액이 Admin Pastor까지 가므로 tier 1, 2는 공통이고,
// $500 초과일 때만 tier 3(finance_chair)을 덧붙인다.
List<ApprovalStep> buildApprovalChain(double amount) {
  final chain = [
    ApprovalStep(tier: 1, role: 'department_head'), // Dept. Chair
    ApprovalStep(tier: 2, role: 'admin_pastor'),    // Admin. Pastor
  ];
  if (amount > 500) {
    chain.add(ApprovalStep(tier: 3, role: 'finance_chair')); // Finance Chair
  }
  return chain;
}
