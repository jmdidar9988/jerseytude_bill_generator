# Jerseytude Bill Generator 🎽🧾

**Jerseytude Bill Generator** is a modern billing, invoicing, and manufacturing order management system crafted specifically for custom jersey and sports apparel businesses (**JERSEYTUDE - Custom Jersey Maker**).

Built with **Flutter**, **Firebase Cloud Firestore**, and **Hive**, the application works seamlessly on Web, Desktop, and Mobile platforms with offline backup and real-time cloud synchronization.

---

## ✨ Key Features

### 1. Dual Invoice Modes
- **Customer Invoices (Retail Selling):**
  - Itemized jersey orders with half-sleeve and full-sleeve customization options.
  - Delivery fees, custom discounts, and partial/advance payment tracking.
  - Payment instructions with bKash Send Money & Bank transfer details (BRAC Bank).
  - Terms & conditions, amount in words (BDT), and print-ready PDF generator.
- **Order Invoices (Factory & Supplier Manufacturing):**
  - Supplier purchase orders for garment factories and printing vendors.
  - Auto-converts jersey descriptions to admin-configured **fixed wholesale prices**.
  - Clearly tracks factory costs, paid deposits, and balance due without retail customer payment info.

### 2. Multi-Invoice Combination & Batch Factory Orders
- Combine multiple customer orders into a single, comprehensive factory order bill.
- **Separate Client & Invoice Breakdown:**
  - Multiple orders from the **same client** remain distinct and separated by invoice number (e.g., `Jisan (JT-2026-1029)` and `Jisan (JT-2026-1035)`).
  - Shows **Project References** on each invoice (e.g., `Sylhet Warriors Tournament`) for fast tracking.
  - Independent per-invoice **Paid Amount** inputs and **Due** calculation.
  - Overall combined totals: Total Pieces, Grand Factory Cost, Total Paid, and Net Balance Due.

### 3. Protected Admin Panel & Fabric Inventory Catalog
- **PIN-Protected Access** (Default PIN: `1234`, customizable inside the panel).
- **Fabric Catalog Management:**
  - Configure fixed order purchase prices (Half Sleeve, Full Sleeve).
  - Configure suggested retail customer selling prices.
  - Real-time price conversion engine matching fabrics in order descriptions.
- **Persistent Storage & Web Session Resilience:**
  - Multi-tier persistence across **SharedPreferences**, **Hive Database**, and **Cloud Firestore**.
  - Dedicated Web URL route (`/#/admin`) ensuring page reloads (F5) never kick the user out of the Admin Panel or drop newly added fabrics.

### 4. Professional PDF Generation & Printing
- Vector-rendered, print-ready PDF invoices formatted in **BDT (Bangladeshi Taka)**.
- Clean typography, official Jersey brand header, dynamic payment status badges (`PAID`, `PARTIAL`, `PENDING`), and multi-group order tables.
- Built-in PDF preview, native print dialog, and file export via `printing` and `pdf`.

### 5. Business Dashboard & Analytics
- Live metrics: Total Revenue, Outstanding Dues, Total Jerseys Manufactured, and Order counts.
- Search and multi-filter invoices by payment status (*Paid, Pending, Partial*) and invoice type (*Customer, Order*).

---

## 🛠️ Technology Stack

- **Framework:** [Flutter](https://flutter.dev/) (Channel stable, SDK `^3.13.7`)
- **Language:** Dart 3
- **Cloud Database:** [Firebase Cloud Firestore](https://firebase.google.com/products/firestore)
- **Local / Offline Storage:** [Hive](https://pub.dev/packages/hive) & [Hive Flutter](https://pub.dev/packages/hive_flutter)
- **State & Preferences:** [Shared Preferences](https://pub.dev/packages/shared_preferences)
- **PDF & Document Printing:** [pdf](https://pub.dev/packages/pdf) & [printing](https://pub.dev/packages/printing)
- **Formatting & Localization:** [intl](https://pub.dev/packages/intl)

---

## 📂 Project Architecture

```text
lib/
├── firebase_options.dart          # Firebase platform configurations
├── main.dart                      # App entry point, Hive bootstrap & Web route setup
├── models/
│   ├── bill.dart                  # Bill model, ClientOrderGroup breakdown logic
│   ├── fabric_item.dart           # Fabric pricing item schema
│   └── order_item.dart            # Line item model
├── screens/
│   ├── admin_panel_screen.dart    # PIN-locked fabric catalog & wholesale price controls
│   ├── analytics_screen.dart      # Business revenue & invoice statistics
│   ├── combine_invoices_screen.dart # Multi-invoice selection & factory order merger
│   ├── create_bill_screen.dart    # Invoice builder (Customer & Order modes)
│   ├── home_screen.dart           # Dashboard, invoice cards, search & filter
│   └── invoice_preview_screen.dart# In-app PDF previewer & print actions
├── services/
│   ├── database_service.dart      # Hive local offline persistence
│   ├── fabric_service.dart        # Fabric catalog, pricing logic & admin auth session
│   ├── firestore_service.dart     # Cloud Firestore real-time sync & auto-increment IDs
│   └── pdf_service.dart           # High-resolution PDF document builder
├── theme/
│   └── app_theme.dart             # Palette (Navy, Royal Blue, Amber, Slate)
├── utils/
│   └── number_to_words.dart       # Converts numerical totals to English words
└── widgets/
    ├── bill_card.dart             # Interactive invoice summary card
    ├── item_dialog.dart           # Item add/edit dialog with fabric picker
    └── stat_card.dart             # Dashboard statistic widget
```

---

## 🚀 Getting Started

### Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (`>= 3.13.7`)
- Google Chrome or Edge (for Flutter Web)
- Android Studio / VS Code with Flutter extension

### Installation

1. **Clone the repository:**
   ```bash
   git clone https://github.com/your-username/jerseytude_bill_generator.git
   cd jerseytude_bill_generator
   ```

2. **Install dependencies:**
   ```bash
   flutter pub get
   ```

3. **Run on Web Server / Chrome:**
   ```bash
   # Run on local web server
   flutter run -d web-server --web-port 8080 --web-hostname 127.0.0.1

   # Or run directly in Chrome
   flutter run -d chrome
   ```

4. **Run on Android / Windows:**
   ```bash
   flutter run -d windows
   # or
   flutter run -d <device-id>
   ```

---

## 🧪 Running Tests

Execute the automated test suite covering models, PDF generation, admin auth persistence, and multi-invoice separation:

```bash
flutter test
```

Analyze codebase for lint compliance:

```bash
flutter analyze
```

---

## 🔒 Security & Admin Access

- **Default Admin PIN:** `1234`
- The PIN can be updated at any time directly through the **Admin Panel** (`Icons.password`).
- Sessions remain securely unlocked in local storage during active browser sessions, but can be locked immediately via the **Logout** button.

---

## 📄 License

This project is proprietary software created for **Jerseytude**. All rights reserved.
