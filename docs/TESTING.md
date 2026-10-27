# Testing

This document describes what is tested in the Church Reimbursement Platform, how to run the tests, and what QA has found so far.

_Last updated: 2026-10-26_

---

## Scope

**Covered by automated tests**

| Area | Code under test |
|------|-----------------|
| Approval chain rules ($500 threshold) | `lib/utils/approval_chain_builder.dart` |
| Approval step serialization | `lib/models/approval_step.dart` |
| Expense defaults and serialization | `lib/models/expense.dart` |

**Not covered yet**

- UI screens (login, home, upload, approver/admin views)
- `Expense.fromFirestore` (needs `fake_cloud_firestore`, see [Planned tests](#planned-tests))
- Firestore security rules (`firestore.rules`)
- OCR Cloud Function (`functions/`)

These are covered by the [manual test checklist](#manual-test-checklist) for now.

---

## Running the tests

```bash
# All tests
flutter test

# A single file
flutter test test/approval_chain_edge_test.dart
```

CI runs `flutter analyze --no-fatal-infos` and `flutter test --reporter expanded` on every push and pull request to `main` (`.github/workflows/flutter-ci.yml`).

---

## Test cases

### `test/approval_chain_builder_test.dart`: core approval rules

| Case | Input | Expected |
|------|-------|----------|
| At or under threshold | `500` | 2 steps: `department_head` (tier 1), `admin_pastor` (tier 2) |
| Over threshold | `500.01` | 3 steps, adds `finance_chair` (tier 3) |
| Boundary | `500.00` / `500.01` | 2 steps / 3 steps |
| Zero | `0` | 2 steps, no error |
| Large amount | `100000` | 3 steps (never more) |

### `test/approval_chain_edge_test.dart`: edge cases around the threshold

| Case | Input | Expected |
|------|-------|----------|
| Just under threshold | `499.99` | 2 steps, roles in order |
| Sub-cent amount | `500.005` | 3 steps (current behavior, see QA-001) |
| Tier order | `750.00` | tiers `[1, 2, 3]` |
| Unique roles | `100`, `1000` | no duplicate roles; last role is `finance_chair` |
| Negative amount | `-50` | 2 steps (current behavior, see QA-002) |
| Initial state | `600` | every step is `pending` with no `approverUid` |

### `test/approval_step_model_test.dart`: `ApprovalStep` toMap / fromMap

| Case | Expected |
|------|----------|
| Round trip with all fields | every field restored unchanged |
| Unknown `status` string | falls back to `pending` |
| Missing `status` | falls back to `pending` |
| Constructor defaults | `pending`, `approverUid` / `actedAt` / `actedBy` / `note` are `null` |
| `actedAt` serialization | written as Firestore `Timestamp`; `null` stays `null` |
| All statuses | each `ApprovalStepStatus` value survives a round trip |

### `test/expense_model_test.dart`: `Expense` defaults and toFirestore

| Case | Expected |
|------|----------|
| Constructor defaults | `draft` false, `approvalChain` empty, `currentTier` 1, `amount` / `description` null |
| `status` | serialized as its name (`'pending'`) |
| `approvalChain` | serialized as a list of maps with `role` and `status` |
| `currentTier`, `draft` | preserved |
| `createdAt` | written as a server timestamp (`FieldValue`) |
| `amount`, `description` | passed through unchanged |

---

## QA findings

| ID | Finding | Impact | Status |
|----|---------|--------|--------|
| QA-001 | Amounts with more than 2 decimal places are not rounded. A user can type `500.005`, which builds a 3-step chain even though it rounds to $500.01 at most, and the stored amount has a fraction of a cent. | Wrong approval tier at the boundary; stored amount isn't a valid currency value. | **Open.** Suggested fix: round to 2 decimals (or reject >2 decimals) in `upload_page.dart` before calling `buildApprovalChain`. |
| QA-002 | `buildApprovalChain` accepts negative amounts and returns a 2-step chain. | None in the app today. | **Mitigated in UI.** The amount field only allows digits and `.`, and submit is blocked when `amount <= 0` (`lib/pages/upload_page.dart`). The builder itself does not validate. |

When a finding is fixed, update its status here and change the matching test from "current behavior" to the intended behavior.

---

## Planned tests

- **`Expense.fromFirestore`**: add `fake_cloud_firestore` to `dev_dependencies`, then check:
  - missing or unknown `status` → `pending`
  - missing `createdAt` → current time
  - missing `draft` → `false`, missing `approvalChain` → `[]`, missing `currentTier` → `1`
  - `amount` stored as `int` → read as `double`
- **Upload amount validation**: empty, `0`, `1.2.3`, more than 2 decimals.
- **Firestore rules**: with the Firebase emulator, confirm members can only read their own expenses and only the assigned approver can approve a step.

---

## Manual test checklist

Run before each release, in English and Korean, on a physical iOS device and an Android device (iOS setup: see README → Running on iOS).

**Member flow**
- [ ] Sign in
- [ ] Upload a receipt photo; OCR fills in the amount
- [ ] Edit the amount and description, then submit
- [ ] Submitting with an empty or `0` amount shows an error
- [ ] The new expense appears on the home screen as pending

**Approval flow**
- [ ] Submit a $500.00 expense: 2 approvers (Dept. Chair → Admin. Pastor)
- [ ] Submit a $500.01 expense: 3 approvers (adds Finance Chair)
- [ ] Each approver sees the expense only when it is their turn
- [ ] Approving the last step marks the expense as approved
- [ ] Rejecting at any step stops the chain

**Language**
- [ ] Login, home, and upload screens show Korean text when the device language is Korean
- [ ] Amounts with commas (e.g. `1,200.00`) are read correctly by OCR
