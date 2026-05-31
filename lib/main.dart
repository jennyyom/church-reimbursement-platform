import 'package:flutter/material.dart';
import 'login_page.dart';

void main() {
  runApp(const ChurchReimbursementApp());
}

class ChurchReimbursementApp extends StatelessWidget {
  const ChurchReimbursementApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Church Reimbursement',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const LoginPage(),
    );
  }
}
