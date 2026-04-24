# RiceAgent - Rice Mill Order Management

RiceAgent is a mobile application designed for rice mill agents to manage orders, customers, and product varieties efficiently. It features offline-first local storage, automatic backups, and Excel-based data importing.

## Excel Import Formats

To import your data from Excel, use the following column structures. The app detects columns based on the header names provided below.

### 1. Customers Import Format
The app searches for these headers in your Excel sheet.

| Recommended Header | Also Accepts | Description |
| :--- | :--- | :--- |
| **Shop Name** | Name, Party | Full name of the shop or party |
| **Place** | City | Location/Town |
| **Phone** | Mobile, Cell, Cell No | Contact phone number |
| **GST** | TIN, GST No | GST or TIN identification number |

*   **Default Column Order:** If no headers are found, the app assumes: `A: Name, B: Place, C: Phone, D: GST`.
*   **Duplicates:** The app skips duplicate customer names to keep your list clean.

### 2. Products (Varieties) Import Format
The app searches for these headers in your Excel sheet.

| Recommended Header | Also Accepts | Description |
| :--- | :--- | :--- |
| **Name** | Variety, Product | Name of the rice variety |
| **Price** | Rate, Cost | Base price per Quintal (Qtl) |
| **GST** | Tax | GST percentage (e.g., `5` or `5%`) |
| **SKU** | Code | Unique product code (optional) |

*   **Default Column Order:** If no headers are found, the app assumes: `A: Name, B: Price, C: GST, D: SKU`.
*   **Price:** Use numbers only (e.g., `5400`).
*   **GST:** Accepts plain numbers or percentages (e.g., `5` or `5%`).

---

## Technical Features
- **Local Database:** Powered by SQLite/Drift for fast, offline access.
- **Auto-Backup:** Daily backups to local storage (last 5 kept).
- **Multi-Customer Orders:** Handle complex lorry loads in a single order flow.
- **Excel Export:** Generates industry-standard order forms for mills.

## Development

This project is built using Flutter.

### Getting Started
1. Install Flutter SDK.
2. Run `flutter pub get` to install dependencies.
3. Run `flutter pub run build_runner build` to generate database code.
4. Run `flutter run` to start the app.
