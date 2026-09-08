import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:church_reimbursement/l10n/app_localizations.dart';

import '../models/expense.dart';
import '../models/app_user.dart';
import 'package:flutter/foundation.dart'; // kIsWeb 체크용
import 'dart:ui' as ui; // 이미지 디코딩 가능 여부 검증용
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart'; // 앱 OCR



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

  // 웹 전용: 사진 고르자마자 만들어지는 draft expense - Submit 전까지는
  // approver/admin/본인 목록에 안 보이고, 나중에 draft: false로 확정됨
  DocumentReference? _draftExpenseRef;
  String? _draftStoragePath;
  bool _isProcessingOcr = false; // 웹에서 업로드+OCR 대기 중 표시용

  @override
  void dispose() {
    _deleteDraftIfAny(); // 확정 안 하고 화면 나가면 최선을 다해 정리 (await는 못 함)
    super.dispose();
  }

  // 이전에 만들어둔 draft(문서+Storage 파일) 삭제 - 사진 다시 고르거나 화면 나갈 때
  Future<void> _deleteDraftIfAny() async {
    final ref = _draftExpenseRef;
    final path = _draftStoragePath;
    _draftExpenseRef = null;
    _draftStoragePath = null;
    if (ref != null) {
      await ref.delete().catchError((_) {}); // 이미 지워졌거나 실패해도 무시
    }
    if (path != null) {
      await FirebaseStorage.instance.ref(path).delete().catchError((_) {});
    }
  }

  // 이미지 선택 + OCR 텍스트 추출
  Future<void> _pickImage({required ImageSource source}) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source);

    if (picked != null) {
      final bytes = await picked.readAsBytes();

      // 실제로 디코딩 가능한 이미지인지 확인 — 확장자만 .jpg인 동영상/손상된 파일 등 걸러냄
      try {
        final codec = await ui.instantiateImageCodec(bytes);
        codec.dispose();
      } catch (_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("This file doesn't look like a valid image. Please choose a photo of your receipt.")),
        );
        return;
      }

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

      // 앱(iOS/Android)에서는 ML Kit OCR 사용 — 온디바이스, 무료, 즉시 결과 나옴
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
      } else {
        // 웹은 온디바이스 OCR이 없어서, Submit 전에 미리 업로드해서
        // Cloud Function OCR을 돌리고 결과를 기다림 (draft 상태로)
        await _uploadDraftAndWaitForOcr();
      }
    }
  }

  // 웹 전용: draft expense 생성 + Storage 업로드 + Cloud Function OCR 결과 대기
  Future<void> _uploadDraftAndWaitForOcr() async {
    await _deleteDraftIfAny(); // 이전에 고른 사진의 draft가 있으면 먼저 정리

    setState(() => _isProcessingOcr = true);
    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final appUser = AppUser.fromFirestore(userDoc.data() as Map<String, dynamic>, uid);

      final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
      final storageRef = FirebaseStorage.instance.ref().child('receipts/$uid/$fileName');

      // draft: true로 생성 - approver/admin/본인 목록엔 아직 안 보임
      final expense = Expense(
        id: '',
        uid: uid,
        churchId: appUser.churchId,
        imageUrl: '',
        storagePath: storageRef.fullPath,
        userName: appUser.name,
        status: ExpenseStatus.pending,
        draft: true,
        createdAt: DateTime.now(),
      );
      final expenseRef = await FirebaseFirestore.instance
          .collection('churches')
          .doc(appUser.churchId)
          .collection('expenses')
          .add(expense.toFirestore());

      _draftExpenseRef = expenseRef;
      _draftStoragePath = storageRef.fullPath;

      await storageRef.putData(_imageBytes!);
      final downloadUrl = await storageRef.getDownloadURL();
      await expenseRef.update({'imageUrl': downloadUrl});

      // 최대 10초까지 OCR 완료 기다렸다가 금액 자동 채우기
      for (int i = 0; i < 10; i++) {
        await Future.delayed(const Duration(seconds: 1));
        final doc = await expenseRef.get();
        if (doc.data() != null && (doc.data() as Map<String, dynamic>)['ocrProcessed'] == true) {
          final amount = (doc.data() as Map<String, dynamic>)['amount'];
          if (amount != null && mounted) {
            setState(() => _amountController.text = (amount as num).toStringAsFixed(2));
          }
          break;
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to process receipt: $e')),
        );
      }
    }
    if (mounted) setState(() => _isProcessingOcr = false);
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
      if (_draftExpenseRef != null) {
        // 웹: 사진 고를 때 이미 만들어둔 draft가 있으면, 확정만 하면 됨
        // (문서/Storage 업로드는 _uploadDraftAndWaitForOcr에서 이미 끝남)
        await _draftExpenseRef!.update({
          'draft': false,
          'amount': double.tryParse(_amountController.text.trim()),
          'description': _descriptionController.text.trim(),
        });
        _draftExpenseRef = null;
        _draftStoragePath = null;
      } else {
        // 앱(네이티브) 경로, 또는 웹에서 draft 생성이 실패해 여기로 떨어진 경우:
        // 처음부터 문서 생성 + 업로드
        final uid = FirebaseAuth.instance.currentUser!.uid;

        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .get();
        final appUser = AppUser.fromFirestore(
          userDoc.data() as Map<String, dynamic>,
          uid,
        );

        final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('receipts/$uid/$fileName');

        // ⚠️ Firestore 문서를 Storage 업로드보다 먼저 생성
        //    Cloud Function(onObjectFinalized)이 업로드 완료 즉시 트리거되므로,
        //    그 시점에 storagePath로 조회할 expense 문서가 이미 존재해야 함
        final expense = Expense(
          id: '',
          uid: uid,
          churchId: appUser.churchId,
          imageUrl: '', // 업로드 완료 후 채움
          storagePath: storageRef.fullPath,
          amount: double.tryParse(_amountController.text.trim()),
          description: _descriptionController.text.trim(),
          userName: appUser.name,
          status: ExpenseStatus.pending,
          createdAt: DateTime.now(),
        );

        final expenseRef = await FirebaseFirestore.instance
            .collection('churches')
            .doc(appUser.churchId)
            .collection('expenses')
            .add(expense.toFirestore());

        await storageRef.putData(_imageBytes!);
        final downloadUrl = await storageRef.getDownloadURL();
        await expenseRef.update({'imageUrl': downloadUrl});

        // 웹인데 draft 생성이 실패했던 경우를 대비한 fallback - OCR 결과 기다림
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
                  // 웹: OCR 처리 중일 때 안내 표시
                  suffixIcon: _isProcessingOcr
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : null,
                  helperText: _isProcessingOcr ? 'Reading amount from receipt…' : null,
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

              // 업로드 버튼 — 이미지 선택 전이거나 OCR 처리 중엔 비활성화
              _isUploading
                  ? const CircularProgressIndicator()
                  : ElevatedButton.icon(
                      onPressed: _imageBytes != null && !_isProcessingOcr ? _uploadReceipt : null,
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