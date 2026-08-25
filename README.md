# Church Reimbursement Platform

> Expense reimbursement and receipt management built for churches and nonprofits.

![Flutter](https://img.shields.io/badge/Flutter-02569B?style=flat&logo=flutter&logoColor=white)
![Firebase](https://img.shields.io/badge/Firebase-FFCA28?style=flat&logo=firebase&logoColor=black)
![Dart](https://img.shields.io/badge/Dart-0175C2?style=flat&logo=dart&logoColor=white)

**Live app:** https://church-reimbursment.web.app

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

| Feature | Status | Description |
|---|---|---|
| Authentication | ✅ | Email/password login with role-based routing |
| Role-Based Access | ✅ | member / approver / admin |
| Receipt Upload | ✅ | Upload receipts via camera or gallery |
| Expense Submission | ✅ | Submit with amount, description, and image |
| Approval Workflow | ✅ | Approver dashboard with approve/reject + reason |
| Admin Dashboard | ✅ | Overview, user management, history, departments, activity codes |
| Export CSV | ✅ | Download all expenses as CSV |
| Localization | ✅ | English, 한국어, Kiswahili |
| OCR | ✅ | Auto-extract amount from receipt images (ML Kit + Cloud Vision, via Firebase Function) |
| AI Parsing | 🔜 | Convert OCR text to structured data (Claude / GPT-4) |
| Planning Center / QuickBooks | 🔜 | Accounting integration |

---

## Tech Stack

| Layer | Technology |
|---|---|
| Frontend | Flutter (iOS, Android, Web) |
| Backend | Firebase (Firestore, Auth, Storage, Functions) |
| OCR | Google ML Kit + Cloud Vision API (via Firebase Functions) |
| AI Parsing | LLM API (planned) |
| Hosting | Firebase Hosting |

---

## Roles

| Role | Permissions |
|---|---|
| member | Submit receipts, view own history |
| approver | Approve or reject pending receipts |
| admin | Manage users, view all expenses, export CSV, manage departments & activity codes |

---

## Data Structure

```
users/{uid}
  - name, email, role, churchId

churches/{churchId}/expenses/{expenseId}
  - uid, userName, churchId
  - imageUrl, amount, description
  - status (pending / approved / rejected)
  - createdAt, approvedBy, approvedAt, rejectReason

churches/{churchId}/departments/{deptId}
  - code, name, chairName, chairUid

churches/{churchId}/activityCodes/{codeId}
  - code, name
  - restrictedTo (department doc IDs; empty = all departments)
```

---

## Installation

```bash
git clone https://github.com/jennyyom/church-reimbursement-platform.git
cd church-reimbursement-platform
flutter pub get
flutter run
```

Firebase config (`lib/firebase_options.dart`) is generated via `flutterfire configure` and already checked into the repo, so no `.env` file is needed to run the app.

To deploy backend changes (Firestore rules, Cloud Functions):

```bash
firebase deploy --only firestore:rules
firebase deploy --only functions
```

To deploy web app changes to the live site (https://church-reimbursment.web.app):

```bash
flutter build web
firebase deploy --only hosting
```

---

## Roadmap

- [x] Authentication + role-based routing (admin / approver / member)
- [x] Localization (EN / KO / SW)
- [x] Receipt upload + Firebase Storage
- [x] Expense submission
- [x] Approver dashboard (approve / reject)
- [x] Admin dashboard (overview / users / history / departments / activity codes)
- [x] Export CSV
- [x] OCR — receipt image → amount (ML Kit + Cloud Vision)
- [ ] AI parsing — text → structured JSON
- [x] Firebase Hosting deployment (redeploy with `firebase deploy --only hosting` after web-affecting changes)
- [ ] Planning Center / QuickBooks integration

---

## Tanzania Considerations

- Offline caching for low connectivity
- M-Pesa payment integration (planned)
- Low-end Android optimization
- Kiswahili localization

---

## License

MIT