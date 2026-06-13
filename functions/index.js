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
    const amountMatches = [...text.matchAll(/\$?\s*(\d+\.\d{2})/g)];
    const amount = amountMatches.length > 0
      ? Math.max(...amountMatches.map(m => parseFloat(m[1])))
      : null;

    // 3. Firestore에서 해당 expense 찾아서 업데이트
    const uid = filePath.split("/")[1]; // receipts/{uid}/{fileName}
    const snapshot = await db
      .collectionGroup("expenses")
      .where("uid", "==", uid)
      .orderBy("createdAt", "desc")
      .limit(1)
      .get();

    if (!snapshot.empty) {
      await snapshot.docs[0].ref.update({
        ocrText: text,
        amount: amount,
        ocrProcessed: true,
      });
    }

    console.log(`OCR 완료: ${filePath}, 금액: ${amount}`);
  } catch (error) {
    console.error("OCR 실패:", error);
  }
});