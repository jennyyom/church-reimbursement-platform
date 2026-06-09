// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get signIn => 'Sign In';

  @override
  String get signOut => 'Sign Out';

  @override
  String get submitReceipt => 'Submit Receipt';

  @override
  String get amount => 'Amount';

  @override
  String get date => 'Date';

  @override
  String get description => 'Description';

  @override
  String get category => 'Category';

  @override
  String get pending => 'Pending';

  @override
  String get approved => 'Approved';

  @override
  String get rejected => 'Rejected';

  @override
  String get approve => 'Approve';

  @override
  String get reject => 'Reject';

  @override
  String get appTitle => 'Church Reimbursement';

  @override
  String get approverDashboard => 'Approver Dashboard';

  @override
  String get adminDashboard => 'Admin Dashboard';

  @override
  String get reviewReceipts => 'Please review receipts pending approval.';

  @override
  String get manageReimbursements => 'Manage and oversee all reimbursements.';
}
