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

| Feature | Status | Description |
|---|---|---|
| Authentication | ✅ | Email/password login with role-based routing |
| Role-Based Access | ✅ | member / approver / admin |
| Receipt Upload | ✅ | Upload receipts via camera or gallery |
| Expense Submission | ✅ | Submit with amount, description, and image |
| Approval Workflow | ✅ | Approver dashboard with approve/reject + reason |
| Admin Dashboard | ✅ | Overview, user management, history |
| Export CSV | ✅ | Download all expenses as CSV |
| Localization | ✅ | English, 한국어, Kiswahili |
| OCR | 🔜 | Auto-extract text from receipt images (ML Kit) |
| AI Parsing | 🔜 | Convert OCR text to structured data (Claude / GPT-4) |
| Planning Center / QuickBooks | 🔜 | Accounting integration |

---

## Tech Stack

| Layer | Technology |
|---|---|
| Frontend | Flutter (iOS, Android, Web) |
| Backend | Firebase (Firestore, Auth, Storage, Functions) |
| OCR | Google ML Kit (planned) |
| AI Parsing | LLM API (planned) |
| Hosting | Firebase Hosting |

---

## Roles

| Role | Permissions |
|---|---|
| member | Submit receipts, view own history |
| approver | Approve or reject pending receipts |
| admin | Manage users, view all expenses, export CSV |

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
```

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
- [x] Receipt upload + Firebase Storage
- [x] Expense submission
- [x] Approver dashboard (approve / reject)
- [x] Admin dashboard (overview / users / history)
- [x] Export CSV
- [ ] OCR — receipt image → text (ML Kit)
- [ ] AI parsing — text → structured JSON
- [ ] Firebase Hosting deployment
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