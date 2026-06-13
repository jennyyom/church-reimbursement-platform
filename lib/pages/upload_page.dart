import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:church_reimbursement/l10n/app_localizations.dart';
import 'dart:typed_data';
import '../models/expense.dart';
import '../models/app_user.dart';
import 'package:flutter/foundation.dart'; // kIsWeb 체크용
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart'; // 앱 OCR
import 'package:flutter_dotenv/flutter_dotenv.dart'; // .env API 키
import 'package:http/http.dart' as http; // Vision API 호출
import 'dart:convert'; // base64, jsonEncode
import 'package:flutter_image_compress/flutter_image_compress.dart'; // 이미지 압축

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

  // 이미지 선택 + OCR 텍스트 추출
  Future<void> _pickImage({required ImageSource source}) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source);

    if (picked != null) {
      final bytes = await picked.readAsBytes();

      // 이미지 압축 — 앱(Android/iOS)에서만, 웹은 미지원
      if (!kIsWeb) {
        final compressed = await FlutterImageCompress.compressWithList(
          bytes,
          minWidth: 1920,
          minHeight: 1920,
          quality: 85,
        );
        setState(() => _imageBytes = compressed);
      } else {
        // 웹은 압축 미지원 — 5MB 초과하면 경고
        if (bytes.lengthInBytes > 5 * 1024 * 1024) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Image is too large. Please choose a smaller image (under 5MB).')),
          );
          return;
        }
        setState(() => _imageBytes = bytes); // 웹은 원본 그대로
      }

      // 앱(iOS/Android)에서는 ML Kit OCR 사용 — 온디바이스, 무료
      if (!kIsWeb) {
        final inputImage = InputImage.fromFilePath(picked.path);
        final recognizer = TextRecognizer();
        final result = await recognizer.processImage(inputImage);
        await recognizer.close();

        // 금액 찾기 (정규식) — 가장 큰 금액을 total로 가정
        final amountRegex = RegExp(r'\$?\d+\.\d{2}');
        final matches = amountRegex.allMatches(result.text);
        if (matches.isNotEmpty) {
          double maxAmount = 0;
          for (final match in matches) {
            final str = match.group(0)!.replaceAll('\$', '');
            final val = double.tryParse(str) ?? 0;
            if (val > maxAmount) maxAmount = val;
          }
          setState(() => _amountController.text = maxAmount.toStringAsFixed(2));
        }
      }
    }
  }

  // 이미지 소스 선택 — 웹은 갤러리 바로, 모바일은 카메라/갤러리 선택
  void _showImageSourcePicker() {
    if (kIsWeb) {
      _pickImage(source: ImageSource.gallery);
      return;
    }
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take a Photo'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(source: ImageSource.camera); // 카메라로 찍기
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from Gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(source: ImageSource.gallery); // 갤러리에서 선택
              },
            ),
          ],
        ),
      ),
    );
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

      // 2. Storage에 이미지 업로드
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
        userName: appUser.name,
        status: ExpenseStatus.pending,
        createdAt: DateTime.now(),
      );

      // Expense Firestore 저장 + 웹에서 OCR 결과 기다리기
      final expenseRef = await FirebaseFirestore.instance
          .collection('churches')
          .doc(appUser.churchId)
          .collection('expenses')
          .add(expense.toFirestore());

      // 웹에서는 Function OCR 결과 기다리기 (최대 10초)
      if (kIsWeb) {
        for (int i = 0; i < 10; i++) {
          await Future.delayed(const Duration(seconds: 1));
          final doc = await expenseRef.get();
          if (doc.data()?['ocrProcessed'] == true) {
            final amount = doc.data()?['amount'];
            if (amount != null && mounted) {
              setState(() => _amountController.text = amount.toStringAsFixed(2));
            }
            break;
          }
        }
      }

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

              // 이미지 선택 버튼 — 모바일은 카메라/갤러리 선택, 웹은 갤러리 바로 열림
              ElevatedButton.icon(
                onPressed: _showImageSourcePicker,
                icon: const Icon(Icons.photo_library),
                label: Text(kIsWeb ? l10n.selectImage : 'Add Photo'),
              ),
              const SizedBox(height: 16),

              // 금액 입력 — OCR로 자동 채워지거나 직접 입력
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

              // 업로드 버튼 — 이미지 선택 전엔 비활성화
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