import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:typed_data';

class UploadPage extends StatefulWidget {
  const UploadPage({super.key});

  @override
  State<UploadPage> createState() => _UploadPageState();
}

class _UploadPageState extends State<UploadPage> {
  Uint8List? _imageBytes;    // 선택한 이미지 데이터
  bool _isUploading = false; // 업로드 중인지 상태

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
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';

      // 1. Firebase Storage에 업로드
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('receipts/$uid/$fileName');

      await storageRef.putData(_imageBytes!);

      // 2. 다운로드 URL 가져오기
      final downloadUrl = await storageRef.getDownloadURL();

      // 3. Firestore에 기록 저장
      await FirebaseFirestore.instance.collection('receipts').add({
        'uid': uid,
        'imageUrl': downloadUrl,
        'status': 'pending', // 승인 대기
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Receipt submitted successfully!')),
      );
      Navigator.pop(context); // 제출 후 홈으로 돌아가기

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Upload failed: $e')),
      );
    }

    setState(() => _isUploading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.indigo.shade50,
      appBar: AppBar(
        title: const Text('Submit Receipt'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 이미지 미리보기
            _imageBytes != null
                ? Image.memory(_imageBytes!, height: 300)
                : Container(
                    height: 300,
                    color: Colors.grey.shade200,
                    child: const Center(
                      child: Text('No image selected'),
                    ),
                  ),
            const SizedBox(height: 24),

            // 이미지 선택 버튼
            ElevatedButton.icon(
              onPressed: _pickImage,
              icon: const Icon(Icons.photo_library),
              label: const Text('Select Image'),
            ),
            const SizedBox(height: 16),

            // 업로드 버튼
            _isUploading
                ? const CircularProgressIndicator()
                : ElevatedButton.icon(
                    onPressed: _imageBytes != null ? _uploadReceipt : null,
                    icon: const Icon(Icons.upload),
                    label: const Text('Submit Receipt'),
                  ),
          ],
        ),
      ),
    );
  }
}