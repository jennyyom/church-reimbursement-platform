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
  String get date => 'Date';

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
  String approverDashboardWithName(String name) {
    return '$name\'s Approver Dashboard';
  }

  @override
  String get adminDashboard => 'Admin Dashboard';

  @override
  String get reviewReceipts => 'Please review receipts pending approval.';

  @override
  String get manageReimbursements => 'Manage and oversee all reimbursements.';

  @override
  String get email => 'Email';

  @override
  String get password => 'Password';

  @override
  String get signInTitle => 'Sign In';

  @override
  String get noAccount => 'Don\'t have an account? Sign up';

  @override
  String get createAccount => 'Create Account';

  @override
  String get name => 'Name';

  @override
  String get inviteCode => 'Invite Code';

  @override
  String get selectImage => 'Select Image';

  @override
  String get uploadFailed => 'Upload failed';

  @override
  String get receiptSubmitted => 'Receipt submitted successfully!';

  @override
  String get submitReceiptTitle => 'Submit Receipt';

  @override
  String get noImageSelected => 'No image selected';

  @override
  String get invalidInviteCode => 'Invalid invite code';

  @override
  String get signupFailed => 'Signup failed';

  @override
  String get amount => 'Amount';

  @override
  String get description => 'Description (optional)';

  @override
  String greeting(String name) {
    return 'Hi, $name! 👋';
  }

  @override
  String get friendFallback => 'Friend';

  @override
  String get tapToUpload => 'Tap to upload';

  @override
  String get myReceipts => 'My Receipts';

  @override
  String get filterAll => 'All';

  @override
  String get noReceiptsYet => 'No receipts yet';

  @override
  String get receiptFallback => 'Receipt';

  @override
  String get deleteReceiptTitle => 'Delete this receipt?';

  @override
  String get deleteReceiptMessage => 'This will remove it from your list.';

  @override
  String get cancel => 'Cancel';

  @override
  String get delete => 'Delete';

  @override
  String get takePhoto => 'Take a Photo';

  @override
  String get chooseFromGallery => 'Choose from Gallery';

  @override
  String get invalidImageFile =>
      'This file doesn\'t look like a valid image. Please choose a photo of your receipt.';

  @override
  String get imageTooLarge =>
      'Image is too large. Please choose a smaller image (under 5MB).';

  @override
  String get processReceiptFailed => 'Failed to process receipt';

  @override
  String get readingAmount => 'Reading amount from receipt…';

  @override
  String get departmentLabel => 'Department *';

  @override
  String get departmentHelper => 'Determines who approves this expense';

  @override
  String get selectDepartmentFirst =>
      'Please select a department before submitting.';

  @override
  String get enterValidAmount =>
      'Please enter a valid amount before submitting.';

  @override
  String get accountNotFound => 'Account not found. Please sign up first.';

  @override
  String get adminWebOnly => 'Admin access is only available on web.';

  @override
  String get loginFailed => 'Login failed';
}
