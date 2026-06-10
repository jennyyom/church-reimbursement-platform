import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:church_reimbursement/l10n/app_localizations.dart';
import 'dart:typed_data';
import '../models/expense.dart';
import '../models/app_user.dart';

class UploadPage extends StatefulWidget {
  const UploadPage({super.key});

  @override
  State<UploadPage> createState() => _UploadPageState();
}

class _UploadPageState extends State<UploadPage> {
  Uint8List? _imageBytes;    // 선택한 이미지 데이터
  bool _isUploading = false; // 업로드 중인지 상태
  final _amountController = TextEditingController();      // 금액 입력
  final _descriptionController = TextEditingController(); // 설명 입력

  // 이미지 선택
  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);

    if (picked != null) {
      final bytes = await picked.readAsBytes();
      setState(() => _imageBytes = bytes);
    }
  }

  // Firebase Storage 업로드 + Firestore 저장
  Future<void> _uploadReceipt() async {
    if (_imageBytes == null) return;

    setState(() => _isUploading = true);

    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      // 1. 유저 정보에서 churchId 가져오기
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      final appUser = AppUser.fromFirestore(
        userDoc.data() as Map<String, dynamic>,
        uid,
      );

      // 2. Storage 업로드
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('receipts/$uid/$fileName');
      await storageRef.putData(_imageBytes!);
      final downloadUrl = await storageRef.getDownloadURL();

      // 3. Expense 모델로 Firestore 저장
      final expense = Expense(
        id: '',
        uid: uid,
        churchId: appUser.churchId,
        imageUrl: downloadUrl,
        amount: double.tryParse(_amountController.text.trim()), // 금액 저장
        description: _descriptionController.text.trim(),        // 설명 저장
        status: ExpenseStatus.pending,
        createdAt: DateTime.now(),
      );

      await FirebaseFirestore.instance
          .collection('churches')
          .doc(appUser.churchId)
          .collection('expenses')
          .add(expense.toFirestore());

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.receiptSubmitted)),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${AppLocalizations.of(context)!.uploadFailed}: $e')),
      );
    }
    setState(() => _isUploading = false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: Colors.indigo.shade50,
      appBar: AppBar(
        title: Text(l10n.submitReceiptTitle),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: SingleChildScrollView(
          child: Column(
            children: [
              // 이미지 미리보기
              _imageBytes != null
                  ? Image.memory(_imageBytes!, height: 200)
                  : Container(
                      height: 200,
                      color: Colors.grey.shade200,
                      child: Center(
                        child: Text(l10n.noImageSelected),
                      ),
                    ),
              const SizedBox(height: 16),

              // 이미지 선택 버튼
              ElevatedButton.icon(
                onPressed: _pickImage,
                icon: const Icon(Icons.photo_library),
                label: Text(l10n.selectImage),
              ),
              const SizedBox(height: 16),

              // 금액 입력
              TextField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: l10n.amount,
                  border: const OutlineInputBorder(),
                  prefixText: '\$ ',
                ),
              ),
              const SizedBox(height: 16),

              // 설명 입력
              TextField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  labelText: l10n.description,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),

              // 업로드 버튼
              _isUploading
                  ? const CircularProgressIndicator()
                  : ElevatedButton.icon(
                      onPressed: _imageBytes != null ? _uploadReceipt : null,
                      icon: const Icon(Icons.upload),
                      label: Text(l10n.submitReceipt),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}