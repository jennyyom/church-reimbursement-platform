const { setGlobalOptions } = require("firebase-functions");
const { onObjectFinalized } = require("firebase-functions/v2/storage");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");
const vision = require("@google-cloud/vision");

initializeApp();
setGlobalOptions({ maxInstances: 10 });

const db = getFirestore();
const visionClient = new vision.ImageAnnotatorClient();

// Storage에 파일 업로드되면 자동 실행
exports.processReceipt = onObjectFinalized(async (event) => {
  const filePath = event.data.name;

  // receipts/ 폴더에 올라온 파일만 처리
  if (!filePath.startsWith("receipts/")) return;

  try {
    // 1. Vision API로 텍스트 추출
    const gcsUri = `gs://${event.data.bucket}/${filePath}`;
    const [result] = await visionClient.textDetection(gcsUri);
    const text = result.fullTextAnnotation?.text || "";

    // 2. 가장 큰 금액을 total로 가정
    // 쉼표 있는 금액(1,234.56)을 먼저 시도한다. 예전 정규식(\d+\.\d{2})은 쉼표 뒤만
    // 읽어서 1,234.56을 234.56으로 잡았고, $1,000 넘는 영수증 금액이 크게 틀어졌다.
    // parseFloat는 쉼표에서 멈추므로 숫자로 바꾸기 전에 쉼표를 지운다.
    const amountMatches = [...text.matchAll(/\$?\s*(\d{1,3}(?:,\d{3})+\.\d{2}|\d+\.\d{2})/g)];
    const amount = amountMatches.length > 0
      ? Math.max(...amountMatches.map(m => parseFloat(m[1].replace(/,/g, ""))))
      : null;

    // 3. Firestore에서 해당 expense 찾아서 업데이트
    const snapshot = await db
      .collectionGroup("expenses")
      .where("storagePath", "==", filePath)
      .limit(1)
      .get();

    if (!snapshot.empty) {
      const doc = snapshot.docs[0];
      // amount를 못 찾았으면(null) 필드 자체를 건드리지 않는다.
      // 그래야 사용자가 이미 입력해둔 금액을 OCR 실패로 덮어써서 지우는 일이 없다.
      const updateData = {
        ocrText: text,
        ocrProcessed: true,
      };
      // amount는 아직 제출 전인 draft(웹에서 사진만 고른 상태)일 때만 채운다.
      // 앱(iOS/Android)은 ML Kit로 금액을 채우고 사용자가 확인한 뒤 제출하는데,
      // 사진이 Storage에 올라가는 건 제출 후라서 이 Function이 나중에 실행된다.
      // 여기서 amount를 덮어쓰면 사용자가 고친 금액이 사라지고, 제출할 때 그 금액으로
      // 정한 승인 단계(500불 이하 2단계 / 초과 3단계)와 금액이 서로 안 맞게 된다.
      // 웹에서도 OCR이 끝나기 전에 Submit을 누르면 draft가 이미 false라서 건드리지 않는다.
      const isDraft = doc.get("draft") === true;
      if (amount !== null && isDraft) {
        updateData.amount = amount;
      }
      await doc.ref.update(updateData);
    }

    console.log(`OCR 완료: ${filePath}, 금액: ${amount}`);
  } catch (error) {
    console.error("OCR 실패:", error);
  }
});