import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:church_reimbursement/l10n/app_localizations.dart';

import '../models/expense.dart';
import '../models/app_user.dart';
import '../models/approval_step.dart'; // _resolveApprovalChain에서 ApprovalStep 타입을 직접 다루기 위해 필요
import 'package:flutter/foundation.dart'; // kIsWeb 체크용
import 'dart:ui' as ui; // 이미지 디코딩 가능 여부 검증용
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart'; // 앱 OCR

// 금액을 넣으면 승인 단계 리스트(ApprovalStep 리스트)를 만들어주는 함수.
// $500 이하 = Dept. Chair 1단계, $500 초과 = Dept. Chair + Admin. Pastor 2단계.
import '../utils/approval_chain_builder.dart';

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

  // 부서(department) 드롭다운용 상태.
  //
  // 승인 체인(approvalChain)의 tier 1(department_head)을 실제로 "누구"에게
  // 보낼지는 departments/{departmentId}.chairUid를 봐야 알 수 있음. 즉 이 지출이
  // 어느 부서 소속인지를 유저가 먼저 골라줘야, 나중 단계에서 부서장 uid를
  // approvalChain에 채워 넣을 수 있음. 그래서 이 화면에서 부서 선택을 필수로 받음.
  String? _selectedDepartmentId; // 유저가 고른 부서 - null이면 아직 선택 안 한 것 (Submit 버튼 비활성화 조건)
  List<QueryDocumentSnapshot>? _departments; // 부서 목록 - null이면 아직 로딩 중

  @override
  void initState() {
    super.initState();
    _loadDepartments(); // 부서 드롭다운은 build()에서 바로 그려야 해서, 다른 메서드처럼 Submit 시점까지 미루지 않고 화면 진입하자마자 불러옴
  }

  // 로그인한 유저가 속한 교회의 부서 목록을 미리 한 번만 불러옴 (부서 드롭다운 렌더링용).
  //
  // 처음엔 부서 목록을 StreamBuilder로 실시간 구독해서 드롭다운을 그렸었는데, Firestore
  // 스트림이 초기 로딩 시 캐시→서버 순으로 거의 동시에 두 번 이벤트를 쏘는 바람에,
  // 유저가 드롭다운을 여는 순간 부모(StreamBuilder)가 다시 빌드되면서 열려있던 드롭다운
  // 메뉴(오버레이)가 자기가 붙어있던 위젯이 사라진 걸로 착각하고 즉시 닫혀버리는 문제가 있었음.
  // 부서 목록은 이 화면에 떠 있는 짧은 시간 동안 실시간으로 바뀔 필요가 없으니, 스트림 대신
  // 한 번만 조회(.get())해서 상태에 저장해두고 그 값으로만 드롭다운을 그리도록 바꿈.
  Future<void> _loadDepartments() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final churchId = userDoc.data()?['churchId'] as String?;

    final deptSnapshot = await FirebaseFirestore.instance
        .collection('churches')
        .doc(churchId)
        .collection('departments')
        .get();

    if (!mounted) return; // 데이터 받아오는 사이에 화면을 나갔으면 setState 하면 안 됨
    setState(() {
      _departments = deptSnapshot.docs;
    });
  }

  // 지금 고른 부서(_selectedDepartmentId)의 "코드 · 이름" 문자열을 만들어줌.
  // 드롭다운 그릴 때 이미 _departments를 통째로 불러와뒀으니, 여기선 추가로
  // Firestore를 조회하지 않고 메모리에 있는 목록에서 찾기만 함. Expense 문서에
  // departmentName으로 그대로 복사해서 저장해두면, 나중에 홈 화면 "My Receipts"에서
  // 부서 이름을 보여줄 때 departmentId로 다시 조회할 필요가 없어짐.
  String? _selectedDepartmentName() {
    final departments = _departments;
    if (departments == null) return null;
    for (final doc in departments) {
      if (doc.id != _selectedDepartmentId) continue;
      final data = doc.data() as Map<String, dynamic>;
      final code = data['code'] as String? ?? '-';
      final name = data['name'] as String? ?? '-';
      return '$code · $name';
    }
    return null; // 선택된 부서가 목록에 없음(이론상 안 일어나야 하지만 방어적으로)
  }

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
      //
      // ⚠️ approvalChain을 여기서 만들지 않는 이유:
      // 이 시점엔 아직 OCR이 끝나지 않아서 금액(_amountController.text)이 확정되지 않았음
      // (사용자가 OCR 결과를 보고 직접 고칠 수도 있음). 만약 여기서 미리 체인을 만들면
      // 아직 확정 안 된 금액 기준으로 "$500 이하니까 1단계" 같은 잘못된 결정을 내려버릴 수 있음.
      // 그래서 체인은 사용자가 Submit 버튼을 눌러서 draft를 확정하는 순간(_uploadReceipt 안,
      // 아래쪽 draft 확정 블록)에 최종 금액을 보고 그때 만듦.
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

  // buildApprovalChain(amount)이 만든 체인은 tier/role만 정해져 있고 approverUid는
  // 항상 null인 상태 (그 함수는 금액만 보고 "몇 단계인지"만 정하지, "누구인지"는 모름).
  // 이 함수가 그 자리에 실제 사람의 uid를 채워 넣는 역할:
  //   - department_head(tier 1) → 이 지출이 속한 부서(departments/{departmentId})의 chairUid
  //   - admin_pastor(tier 2)    → 이 교회(churches/{churchId})에 지정된 adminPastorUid
  //     (Admin 페이지 Departments 탭 상단에서 admin이 지정한 값)
  //
  // 부서장/Admin Pastor가 아직 지정 안 돼 있으면(chairUid나 adminPastorUid가 비어있으면)
  // approverUid는 null로 남음 - 이 경우 그 단계는 "담당자 미배정" 상태가 되고, 나중에
  // ApproverPage 필터링(다음 단계에서 만들 예정)에서 아무한테도 안 보이게 됨. 지출 자체는
  // 정상 제출되니, admin이 나중에 담당자를 지정하면 그때부터 보이기 시작하는 게 의도된 동작.
  Future<List<ApprovalStep>> _resolveApprovalChain(
    List<ApprovalStep> chain,
    String churchId,
    String departmentId,
  ) async {
    final deptDoc = await FirebaseFirestore.instance
        .collection('churches')
        .doc(churchId)
        .collection('departments')
        .doc(departmentId)
        .get();
    final chairUid = deptDoc.data()?['chairUid'] as String?;

    final churchDoc = await FirebaseFirestore.instance.collection('churches').doc(churchId).get();
    final adminPastorUid = churchDoc.data()?['adminPastorUid'] as String?;

    return chain.map((step) {
      // chairUid는 부서 문서에 ''(빈 문자열)로 저장되는 경우가 있어서(미배정 부서장) -
      // 빈 문자열을 그대로 approverUid에 넣으면 "누군가한테 배정된 것처럼" 보이니 null로 취급
      final resolvedUid = switch (step.role) {
        'department_head' => (chairUid != null && chairUid.isNotEmpty) ? chairUid : null,
        'admin_pastor' => adminPastorUid,
        _ => null,
      };
      return ApprovalStep(tier: step.tier, role: step.role, approverUid: resolvedUid);
    }).toList();
  }

    // Firebase Storage 업로드 + Firestore 저장
  Future<void> _uploadReceipt() async {
    if (_imageBytes == null) return;
    // 버튼이 이미 _selectedDepartmentId != null일 때만 눌리게 돼 있어서 평소엔 여기 안 걸리지만,
    // 방어적으로 한 번 더 확인 (예: 코드가 나중에 바뀌어 버튼 조건이 느슨해지는 실수를 대비)
    if (_selectedDepartmentId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a department before submitting.')),
      );
      return;
    }
    setState(() => _isUploading = true);

    try {
      if (_draftExpenseRef != null) {
        // 웹: 사진 고를 때 이미 만들어둔 draft가 있으면, 확정만 하면 됨
        // (문서/Storage 업로드는 _uploadDraftAndWaitForOcr에서 이미 끝남)

        // 여기가 바로 "금액이 진짜로 확정되는 순간"임 — 사용자가 OCR 결과를 그대로 두거나
        // 직접 수정한 뒤 Submit을 누른 시점이라, 이제서야 approvalChain을 안전하게 만들 수 있음.
        // buildApprovalChain(amount)가 이 금액을 보고 $500 이하/초과를 판단해서
        // 승인 단계 리스트(1단계 or 2단계)를 만들어줌.
        final amount = double.tryParse(_amountController.text.trim()) ?? 0;

        // draft 생성 경로(_uploadDraftAndWaitForOcr)는 churchId를 따로 상태에 안 남겨뒀어서,
        // approverUid를 채우려면(churches/{churchId} 조회가 필요) 여기서 한 번 더 불러옴
        final uidForChurch = FirebaseAuth.instance.currentUser!.uid;
        final userDocForChurch = await FirebaseFirestore.instance.collection('users').doc(uidForChurch).get();
        final churchId = userDocForChurch.data()?['churchId'] as String;

        // buildApprovalChain은 role/tier만 정하고, _resolveApprovalChain이 그 자리에
        // 실제 부서장·Admin Pastor의 uid를 채워 넣음 (자세한 설명은 _resolveApprovalChain 주석 참고)
        final resolvedChain = await _resolveApprovalChain(
          buildApprovalChain(amount),
          churchId,
          _selectedDepartmentId!,
        );

        await _draftExpenseRef!.update({
          'draft': false,
          'amount': amount,
          'description': _descriptionController.text.trim(),
          // 화면에서 고른 부서 - 다음 단계(승인자 uid 채워넣기)에서
          // departments/{departmentId}.chairUid를 찾는 데 씀
          'departmentId': _selectedDepartmentId,
          // 부서 "이름"까지 같이 저장 - 홈 화면(My Receipts)에서 부서를 보여줄 때
          // departmentId로 다시 조회 안 해도 되게 (_selectedDepartmentName 주석 참고)
          'departmentName': _selectedDepartmentName(),
          // ApprovalStep 객체 리스트는 그대로 Firestore에 못 넣으니까,
          // 각 ApprovalStep을 .toMap()으로 Map(딕셔너리) 형태로 바꿔서 리스트로 저장함.
          'approvalChain': resolvedChain.map((s) => s.toMap()).toList(),
          'currentTier': 1, // 새로 확정된 지출은 항상 1단계(부서장)부터 시작
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
        //    (예전엔 업로드를 먼저 해서 Function이 문서를 못 찾고 조용히 실패했었음)

        // 이 경로(네이티브 앱)는 ML Kit OCR이 이미지 고를 때 바로 끝나서 금액이
        // 이 시점에 이미 확정돼 있음 (draft 대기 과정이 필요 없음). 그래서 바로
        // approvalChain을 만들어서 Expense 생성할 때 같이 넣어줌.
        // (buildApprovalChain은 role/tier만 정하고, _resolveApprovalChain이 그 자리에
        // 실제 부서장·Admin Pastor의 uid를 채워 넣음 — 위 draft 경로와 동일한 이유)
        final amount = double.tryParse(_amountController.text.trim()) ?? 0;
        final resolvedChain = await _resolveApprovalChain(
          buildApprovalChain(amount),
          appUser.churchId,
          _selectedDepartmentId!,
        );
        final expense = Expense(
          id: '',
          uid: uid,
          churchId: appUser.churchId,
          imageUrl: '', // 업로드 완료 후 채움
          storagePath: storageRef.fullPath,
          amount: amount,
          description: _descriptionController.text.trim(),
          // 화면에서 고른 부서 - departments/{departmentId}.chairUid를 approvalChain에
          // 채워 넣는 데 이미 위(_resolveApprovalChain)에서 씀
          departmentId: _selectedDepartmentId,
          // 부서 "이름"까지 같이 저장 - 홈 화면(My Receipts)에서 보여줄 때 씀
          departmentName: _selectedDepartmentName(),
          userName: appUser.name,
          status: ExpenseStatus.pending,
          createdAt: DateTime.now(),
          approvalChain: resolvedChain, // 실제 승인자 uid까지 채워진 체인
          currentTier: 1,                // 1단계(부서장)부터 시작
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
              // 위에서 만든 'amount' 변수(local variable)랑 이름이 겹치면 안 되니까
              // 'ocrAmount'라는 다른 이름으로 받음
              final ocrAmount = doc.data()?['amount'];
              if (ocrAmount != null && mounted) {
                setState(() => _amountController.text = ocrAmount.toStringAsFixed(2));
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
              const SizedBox(height: 16),

              // 부서 선택 — 이 지출이 어느 부서 소속인지 골라야 함.
              // 나중에 이 값(departmentId)으로 departments/{departmentId}.chairUid를 찾아서
              // approvalChain의 tier 1(department_head) 승인자를 정하게 됨.
              //
              // _departments가 아직 null이면(_loadChurchIdAndDepartments 진행 중) 로딩 스피너만 보여줌.
              // 부서 목록을 한 번만 불러와 상태에 저장해두고 그 값으로 그리기 때문에(위 _loadChurchIdAndDepartments
              // 주석 참고), 드롭다운을 여는 동안 부모가 다시 빌드돼서 메뉴가 저절로 닫히는 일이 없음.
              _departments == null
                  ? const Center(child: CircularProgressIndicator())
                  : Builder(builder: (context) {
                      final departments = _departments!;

                      // 고른 부서가 목록에 없으면(관리자가 그 사이 부서를 삭제한 경우 등)
                      // Dropdown의 value가 items 목록에 없는 상태가 되어 Flutter가 assertion
                      // 에러를 던짐 - 그래서 실제 목록에 있는 id인지 확인해서 없으면
                      // 화면엔 "선택 안 함" 상태로 보여줌
                      final validIds = departments.map((d) => d.id).toSet();
                      final dropdownValue = validIds.contains(_selectedDepartmentId) ? _selectedDepartmentId : null;

                      return DropdownButtonFormField<String>(
                        value: dropdownValue,
                        decoration: const InputDecoration(
                          labelText: 'Department *',
                          border: OutlineInputBorder(),
                          helperText: 'Required — determines who approves this expense',
                        ),
                        items: departments.map((doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          final code = data['code'] as String? ?? '-';
                          final name = data['name'] as String? ?? '-';
                          return DropdownMenuItem(
                            value: doc.id,
                            child: Text('$code · $name'),
                          );
                        }).toList(),
                        onChanged: (value) => setState(() => _selectedDepartmentId = value),
                      );
                    }),
              const SizedBox(height: 24),

              // 업로드 버튼 — 이미지 선택 전이거나 OCR 처리 중이거나 부서 미선택이면 비활성화.
              // 부서를 필수로 막는 이유: departmentId 없이 제출되면 나중에 tier 1(부서장)
              // 승인자를 찾을 방법이 없어서, 승인 체인이 아무한테도 안 가는 지출이 생겨버림.
              _isUploading
                  ? const CircularProgressIndicator()
                  : ElevatedButton.icon(
                      onPressed: _imageBytes != null && !_isProcessingOcr && _selectedDepartmentId != null
                          ? _uploadReceipt
                          : null,
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