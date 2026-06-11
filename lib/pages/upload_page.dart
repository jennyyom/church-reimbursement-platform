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
  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);

    if (picked != null) {
      final bytes = await picked.readAsBytes();
      setState(() => _imageBytes = bytes);

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

      // 웹에서는 Google Cloud Vision API 사용
      if (kIsWeb) {
        await _extractAmountFromImage(bytes);
      }
    }
  }

  // Google Cloud Vision API로 영수증에서 금액 추출 (웹 전용)
  Future<void> _extractAmountFromImage(Uint8List imageBytes) async {
    try {
      // .env에서 API 키 가져오기
      final apiKey = dotenv.env['GOOGLE_VISION_API_KEY'] ?? '';
      final base64Image = base64Encode(imageBytes);

      // Vision API 호출
      final response = await http.post(
        Uri.parse('https://vision.googleapis.com/v1/images:annotate?key=$apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'requests': [
            {
              'image': {'content': base64Image},
              'features': [{'type': 'TEXT_DETECTION'}],
            }
          ]
        }),
      );

      final data = jsonDecode(response.body);
      final text = data['responses'][0]['fullTextAnnotation']['text'] as String;

      // 금액 찾기 — 가장 큰 숫자를 total로 가정
      final amountRegex = RegExp(r'\$?\d+\.\d{2}');
      final matches = amountRegex.allMatches(text);
      if (matches.isNotEmpty) {
        double maxAmount = 0;
        for (final match in matches) {
          final str = match.group(0)!.replaceAll('\$', '');
          final val = double.tryParse(str) ?? 0;
          if (val > maxAmount) maxAmount = val;
        }
        setState(() => _amountController.text = maxAmount.toStringAsFixed(2));
      }
    } catch (e) {
      debugPrint('OCR error: $e');
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

              // 이미지 선택 버튼 — 탭하면 갤러리 열림
              ElevatedButton.icon(
                onPressed: _pickImage,
                icon: const Icon(Icons.photo_library),
                label: Text(l10n.selectImage),
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