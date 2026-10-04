# Split Expense (E-split)

iOS app for splitting group expenses, tracking who owes whom, and recording settlements. Built with SwiftUI, MVVM, SwiftData, and Supabase for accounts and shared data.

**Display name:** Split Expense  
**Bundle identifier:** `shubhamchiplunkar.E-split`  
**Version:** 1.0

---

## Overview

Split Expense helps people share costs in trips, homes, friend groups, and similar settings. A user creates an account, creates or joins a group, adds expenses with a split method, and sees balances derived from those expenses. Settlements mark a debt as paid in the app only. The app does **not** send money, open UPI, or talk to a payment gateway.

When `SUPABASE_URL` and `SUPABASE_ANON_KEY` are set, authentication and group, expense, and settlement data go through Supabase. SwiftData remains the on-device cache (and the full store if Supabase is not configured).

---

## Purpose

- Keep a shared record of group spending
- Split costs fairly (equal, exact, percentage, or shares)
- Show who owes whom in plain language
- Record that a settlement was marked paid
- Let signed-in users join groups via invite links

---

## Current features

- [x] Email / password registration and login
- [x] Logged-in home screen of groups
- [x] Create group (optional type: Trip, Home, Friends, Couple, Office, Custom)
- [x] Creator added as Admin; other members as Member
- [x] Group dashboard: totals, you owe / you are owed, members, balances, recent expenses
- [x] Edit / archive / delete group (admin)
- [x] Invite link / code (`esplit://join/CODE`)
- [x] Join with code (signed-in users only)
- [x] Add member by **existing account email** (remote)
- [x] Add / edit / delete expenses
- [x] Categories (Food, Hotel, Transport, Entertainment, Shopping, Medical, Rent, Utilities, Travel, Other)
- [x] Split methods: equal, exact amount, percentage, shares
- [x] Balance screen with simplified “who owes whom”
- [x] Record settlement and mark as paid (status only)
- [x] Expense history with search and filters (category, member, date, amount)
- [x] Local notifications for expense added/updated and settlement reminders
- [x] SwiftData persistence and offline cache
- [x] Supabase Auth + Postgres (when configured)
- [x] Dark mode and basic empty / error states

**Not built yet (placeholders or future work):**

- [ ] Swift Charts analytics (screen is a placeholder: “Analytics coming next”)
- [ ] Sign in with Apple / Google
- [ ] Receipt OCR, attachments, recurring expenses
- [ ] Multi-currency conversion
- [ ] Real payments (UPI, bank, gateways)

---

## Planned / future features

| Area | Direction |
| --- | --- |
| Payments | UPI, bank transfer, or a payment provider — **not** in this version |
| Analytics | Spending by category, over time, member contributions (Swift Charts) |
| Auth | Additional providers |
| Groups | QR join, richer activity feed, push notifications |
| Data | Stronger sync, export (PDF/CSV) |

---

## Technology stack

| Layer | Choice |
| --- | --- |
| Language | Swift 5 |
| UI | SwiftUI, `NavigationStack` |
| Architecture | MVVM + repositories |
| Observation | `@Observable` view models |
| Local data | SwiftData |
| Remote data | Supabase (Auth + Postgres + RLS) via `supabase-swift` |
| Concurrency | `async/await` |
| Notifications | UserNotifications |
| Tests | XCTest (unit); light UI launch test |

**Deployment:** iOS **26.0** (iPhone and iPad). Open the project with a matching Xcode (the project targets the iOS 26 SDK).

Third-party package: [supabase-swift](https://github.com/supabase/supabase-swift) (product `Supabase`).

---

## Architecture

```text
Views
  ↓
ViewModels
  ↓
Repositories
  ↓
Data Sources
  ├── LocalDataSource (SwiftData)
  └── RemoteBackend (Supabase, optional)
```

- **Views** render state and send actions. They do not run split math or SwiftData fetches.
- **ViewModels** validate input, call repositories, and prepare display data.
- **Repositories** (`AuthRepository`, `GroupRepository`, `ExpenseRepository`, `SettlementRepository`) hide storage. If Supabase is enabled, they write remote first, then cache locally. Reads prefer remote and fall back to SwiftData on failure.
- **Services** (`ExpenseCalculationService`, `BalanceService`, `NotificationService`) hold financial and notification logic.
- **`AppDependencies`** wires live repositories. Tests inject in-memory fakes.

SwiftData is always present. Supabase is used when `Info.plist` contains a real `https://` project URL and a non-placeholder anon key.

---

## Persistence

SwiftData container `SplitExpense_v2` stores:

- `UserAccountEntity` (local email accounts when remote is off)
- `GroupEntity`
- `GroupMemberEntity`
- `ExpenseEntity`
- `ExpenseSplitEntity`
- `SettlementEntity`

With Supabase enabled, Postgres tables (`profiles`, `groups`, `group_members`, `expenses`, `expense_splits`, `settlements`) are the shared source of truth. RLS and RPCs (`join_group`, `preview_group`, `add_member_by_email`) restrict access to members and admins.

---

## Core models

```text
User (account)
  └── Group (createdBy)
        ├── GroupMember (userId, role: admin | member)
        ├── Expense (paidBy, category, splitMethod)
        │     └── ExpenseSplit (userId, amount, optional % / shares)
        └── Settlement (fromUser, toUser, status: pending | paid)
```

Balances are **not** stored as a running ledger. They are computed from expenses and **paid** settlements.

---

## Expense splitting

`ExpenseCalculationService` requires:

- Amount greater than zero
- At least one participant
- Sum of split amounts equals the expense total (after cent rounding)

| Method | Rule |
| --- | --- |
| Equal | Total divided across participants; leftover cents distributed |
| Exact amount | Entered amounts must sum to the total |
| Percentage | Percents must sum to 100% |
| Shares | Amounts proportional to share counts |

Invalid splits are not persisted.

---

## Balance calculation

For each expense:

- Payer **+** total amount
- Each participant **−** their share

Paid settlements move net the other way (the person who marked the settlement paid reduces what they owe). Pending settlements do **not** change balances.

**Zero-sum rule:** for every group, after rounding,

```text
sum of all member net balances = 0
```

`BalanceService.validateZeroSum` enforces this. Simplified debts pair largest debtors with largest creditors so the UI can say “Rahul owes you ₹1,200” instead of exposing a ledger.

---

## Settlements

A settlement is a **record** that someone intends to pay (or has marked paid) another member.

1. Open Settlements from the group
2. Record a suggested debt
3. Tap **Mark as Paid** → status `paid`, `settledAt` set

**This version does not process real money.** No UPI, bank transfer, payment gateway, or payment verification. Those are planned for later updates.

---

## Auth, invites, and members

### Login (current Supabase project setup)

- Confirm email is **disabled** in Supabase so signup can sign in immediately.
- Users **create an account** if they do not have one.
- Password **minimum length is 6 characters**, enforced by Supabase Auth (Authentication → Providers → Email).
- After a successful signup or login, the session is stored and the groups list appears.

### Invites

- Each group has an invite code. Share `esplit://join/CODE` (or join by code in the app).
- The invitee must **already be logged in**. `RootView` only opens the join sheet when `isLoggedIn` is true.
- Only users who have created an account can use an invite link.
- Join uses the `join_group` RPC so the invitee does not need to be a member already.

### Adding members

- Prefer the invite link for people who will create their own account.
- **Add Member** on the remote backend looks up a `profiles` row by email (`add_member_by_email`). There is no row for people who have never signed up; the app asks them to register first or use the invite after they have an account.

---

## Main user flow

```text
Create account / Log in
        ↓
Create group  (or Join via invite / code)
        ↓
Group dashboard
        ↓
Add expense → who paid → split method → save
        ↓
Balances (who owes whom)
        ↓
Record settlement → Mark as paid
```

---

## Project structure

```text
E-split/
├── E_splitApp.swift
├── App/AppDependencies.swift
├── Core/          Constants, Errors, Extensions, Services, Utilities
├── Models/        Domain types
├── Features/      Auth, Groups, Expenses, Balances, Settlements, Analytics
│                  └── Views + ViewModels
├── Repositories/
├── Persistence/   SwiftData entities, LocalDataSource, Remote (Supabase)
└── Info.plist     URL scheme + Supabase keys

E-splitTests/      Unit tests
E-splitUITests/    Launch smoke test
supabase/schema.sql
```

---

## Setup and run

### Requirements

- macOS with Xcode that supports **iOS 26**
- Apple Developer signing (Automatic) for device or simulator
- A [Supabase](https://supabase.com) project for shared login and data

### 1. Clone and open

```bash
git clone https://github.com/chiplunkarshubham09/e-split.git
cd e-split
open E-split.xcodeproj
```

Let Xcode resolve the Supabase Swift package.

### 2. Database

In the Supabase SQL Editor, run **all of** `supabase/schema.sql` (safe to re-run). It creates tables, the profile trigger, RPCs, and RLS.

### 3. Auth settings (this project)

In **Authentication → Providers → Email**:

- **Enable** the Email provider
- **Confirm email:** off (so users are not blocked waiting for a confirmation mail)
- **Minimum password length:** 6

### 4. App keys

In `E-split/Info.plist` (Project Settings → API):

```xml
<key>SUPABASE_URL</key>
<string>https://YOUR_PROJECT.supabase.co</string>
<key>SUPABASE_ANON_KEY</key>
<string>your-anon-key</string>
```

Use the **project URL** only (no `/rest/v1/`). Use the **anon** key, never `service_role`.

If these keys are empty, the app stays local-only (unit tests use that path).

### 5. URL scheme

`esplit` is registered for invite deep links (`esplit://join/...`).

### 6. Run

Select the **E-split** scheme, an iOS 26 simulator or device, and press Run.

---

## Testing

Unit tests live under `E-splitTests/`:

| Area | Coverage |
| --- | --- |
| `ExpenseCalculationServiceTests` | Equal / exact / % / shares, rounding, invalid totals |
| `BalanceServiceTests` | Single and multiple expenses, settlements, zero-sum |
| `ViewModelTests` | Create group, add member, add/delete expense, record/mark settlement |
| `AuthAndInviteTests` | Register/login, invite URL parsing, join by code, auth error mapping |

```bash
xcodebuild -project E-split.xcodeproj -scheme E-split \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:E-splitTests test
```

UI tests currently check that login or the Groups bar appears on launch. A full UI path (create group → expense → settle) is not automated yet.

---

## Development status

The core split flow is implemented: accounts, groups, invites, expenses, balances, and status-only settlements, with SwiftData plus Supabase. Analytics is a placeholder. Payment rails are out of scope for this version. Treat this as a working MVP, not a production payments product.

---

## Future improvements

- Payment integrations (UPI, bank transfers, gateways) — explicitly deferred
- Charts and member contribution analytics
- Richer sync and conflict handling
- Additional auth providers
- Export and receipts
- Broader UI tests
