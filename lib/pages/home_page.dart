import 'package:flutter/material.dart';
import 'upload_page.dart';
import '../main.dart';
import 'package:church_reimbursement/l10n/app_localizations.dart';

// User 화면 (영수증 제출)
class UserHomePage extends StatelessWidget {
  const UserHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.indigo.shade50,
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.appTitle),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
  icon: const Icon(Icons.language),
  onPressed: () {
    showModalBottomSheet(
      context: context,
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            title: const Text('English'),
            onTap: () {
              ChurchReimbursementApp.of(context)?.setLocale(const Locale('en'));
              Navigator.pop(context);
            },
          ),
          ListTile(
            title: const Text('한국어'),
            onTap: () {
              ChurchReimbursementApp.of(context)?.setLocale(const Locale('ko'));
              Navigator.pop(context);
            },
          ),
          ListTile(
            title: const Text('Kiswahili'),
            onTap: () {
              ChurchReimbursementApp.of(context)?.setLocale(const Locale('sw'));
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  },
),
        ],
      ),
      body: Center(
  child: ElevatedButton.icon(
    onPressed: () {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const UploadPage()),
      );
    },
    icon: const Icon(Icons.receipt_long),
    label: Text(AppLocalizations.of(context)!.submitReceipt),
  ),
),
    );
  }
}

// Approver 화면 (영수증 승인/거절)
class ApproverHomePage extends StatelessWidget {
  const ApproverHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.orange.shade50,
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.approverDashboard),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
  icon: const Icon(Icons.language),
  onPressed: () {
    showModalBottomSheet(
      context: context,
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            title: const Text('English'),
            onTap: () {
              ChurchReimbursementApp.of(context)?.setLocale(const Locale('en'));
              Navigator.pop(context);
            },
          ),
          ListTile(
            title: const Text('한국어'),
            onTap: () {
              ChurchReimbursementApp.of(context)?.setLocale(const Locale('ko'));
              Navigator.pop(context);
            },
          ),
          ListTile(
            title: const Text('Kiswahili'),
            onTap: () {
              ChurchReimbursementApp.of(context)?.setLocale(const Locale('sw'));
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  },
),
        ],
      ),
      body: Center(
        child: Text(
          AppLocalizations.of(context)!.reviewReceipts,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 24),
        ),
      ),
    );
  }
}

// Admin 화면 (관리자 - 전체 관리)
class AdminHomePage extends StatelessWidget {
  const AdminHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.red.shade50,
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.adminDashboard),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
  icon: const Icon(Icons.language),
  onPressed: () {
    showModalBottomSheet(
      context: context,
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            title: const Text('English'),
            onTap: () {
              ChurchReimbursementApp.of(context)?.setLocale(const Locale('en'));
              Navigator.pop(context);
            },
          ),
          ListTile(
            title: const Text('한국어'),
            onTap: () {
              ChurchReimbursementApp.of(context)?.setLocale(const Locale('ko'));
              Navigator.pop(context);
            },
          ),
          ListTile(
            title: const Text('Kiswahili'),
            onTap: () {
              ChurchReimbursementApp.of(context)?.setLocale(const Locale('sw'));
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  },
),
        ],
      ),
      body: Center(
        child: Text(
          AppLocalizations.of(context)!.manageReimbursements,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 24),
        ),
      ),
    );
  }
}