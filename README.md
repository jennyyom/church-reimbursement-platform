# Church Reimbursement Platform

> Expense reimbursement and receipt management built for churches and nonprofits.

![Flutter](https://img.shields.io/badge/Flutter-02569B?style=flat&logo=flutter&logoColor=white)
![Firebase](https://img.shields.io/badge/Firebase-FFCA28?style=flat&logo=firebase&logoColor=black)
![Dart](https://img.shields.io/badge/Dart-0175C2?style=flat&logo=dart&logoColor=white)

---

## Why

Church finance teams still manage reimbursements with paper receipts, email threads, and spreadsheets. This app replaces that workflow with receipt scanning, AI-assisted parsing, and a structured approval process — designed to work across the US and Tanzania.

---

## Screenshots

> Coming soon — MVP in progress.

<!-- Add screenshots/GIFs here once available
![Login Screen](docs/screenshots/login.png)
![Expense Submission](docs/screenshots/expense.png)
![Admin Dashboard](docs/screenshots/admin.png)
-->

---

## Features

| Feature | Description |
|---|---|
| Receipt Scanning | Upload receipts via mobile camera with OCR extraction |
| AI Parsing | Automatic amount, date, and vendor detection |
| Expense Submission | Categorize by ministry or fund with notes and attachments |
| Approval Workflow | Admin approve/reject dashboard with audit trail |
| Export | CSV and Excel export for accounting integration |
| Localization | English, 한국어, Kiswahili |

---

## Tech Stack

| Layer | Technology |
|---|---|
| Frontend | Flutter (iOS, Android, Web) |
| Backend | Firebase (Firestore, Auth, Storage, Functions) |
| OCR | Google ML Kit / Vision API |
| AI Parsing | LLM API |
| Hosting | Firebase Hosting |

---

## Installation

```bash
git clone https://github.com/your-repo/church-reimbursement-platform.git
cd church-reimbursement-platform
flutter pub get
flutter run
```

Create a `.env` file:

```
FIREBASE_API_KEY=
FIREBASE_PROJECT_ID=
VISION_API_KEY=
LLM_API_KEY=
```

---

## Roadmap

- [x] Authentication + role-based routing (admin / approver / member)
- [x] Localization (EN / KO / SW)
- [ ] Receipt upload + OCR
- [ ] Expense submission
- [ ] Admin approval dashboard
- [ ] Reporting & export
- [ ] Planning Center / QuickBooks integration

---

## License

MIT