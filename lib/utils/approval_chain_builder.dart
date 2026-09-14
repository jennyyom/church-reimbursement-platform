import '../models/approval_step.dart';

List<ApprovalStep> buildApprovalChain(double amount) {
  if (amount > 500) {
    return [
      ApprovalStep(tier: 1, role: 'department_head'), // Dept. Chair
      ApprovalStep(tier: 2, role: 'admin_pastor'),    // Admin. Pastor
    ];
  } else {
    return [
      ApprovalStep(tier: 1, role: 'department_head'), // Dept. Chair
    ];
  }
}