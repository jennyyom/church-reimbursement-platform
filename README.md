# Church Reimbursement Platform

A cross-platform expense and reimbursement management system designed for churches and nonprofit organizations.

Built with Flutter and Firebase, supporting Web, Android, and iOS.

---

## Key Features

### Receipt Processing
- Capture or upload receipt images
- OCR-based text extraction (planned)
- Automatic detection of amount, date, and vendor

### Expense Management
- Submit reimbursement requests
- Ministry / fund categorization
- Attach receipts and notes
- Track submission history

### Approval Workflow
- Admin approval and rejection flow
- Status tracking (Pending / Approved / Rejected)
- Role-based access control (planned)

### Reporting
- CSV / Excel export for accounting
- Monthly summaries
- Audit-friendly records

---

## Tech Stack

- Flutter
- Firebase
- Firebase Authentication
- Cloud Firestore
- Firebase Storage
- Google ML Kit (planned for OCR)
- LLM API (planned for AI parsing)

---

## Architecture

Receipt Upload → OCR Processing → Data Structuring → Approval Workflow → Export / Reporting

---

## Project Goals

- Eliminate paper-based reimbursement workflows
- Reduce manual accounting work
- Improve financial transparency
- Provide a simple expense system for churches

---

## Security

- Firebase Authentication
- Firestore security rules
- Secure cloud storage
- HTTPS communication

---

## Roadmap

### MVP
- Authentication
- Receipt upload
- Expense submission
- Admin approval

### Enhancement
- Notifications
- UI improvements
- Error handling

### Expansion
- Multi-church support
- Accounting integrations
- Analytics dashboard

---

## Setup

```bash
git clone https://github.com/jennyyom/church-reimbursement-platform.git
cd church-reimbursement-platform
flutter pub get
flutter run