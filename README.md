# POS Desktop Application

**POS Desktop** is a powerful and lightweight Point of Sale (POS) system designed to manage products, sales, purchases, and reports entirely offline. Built using **Flutter** for a modern UI and **SQLite** for local storage, this application runs on Windows and does not require an internet connection, making it ideal for small and medium businesses.

## Features

- **Offline First:** Works 100% without an internet connection. All data is stored locally on your machine.
- **Product Management:** Easily add, edit, and remove products, including categories, prices, stock, and barcodes.
- **Sales Module:** Create invoices, manage a shopping cart, and track sales in real time.
- **Purchase Module:** Record purchase invoices and manage stock updates.
- **Reports & Analytics:** Generate reports such as:
  - Sales report
  - Purchases report
  - Profit report
  - Top-selling products
  - Purchased items
  - Sold items
- **Barcode Scanner Support:** Add products quickly using a barcode scanner or manually entering the barcode.
- **Interactive UI:** Modern interface with hover effects, dynamic grids, and responsive controls.
- **Theming:** Supports both light and dark modes.
- **Local Database:** SQLite database is fully integrated within the project, easy to back up or move.
- **User Notifications:** Inline notifications for success/error events instead of intrusive popups.

## Screenshots

*(You can add screenshots of your main interface, barcode reader, shopping cart, and reports here)*

## Installation

1. Clone the repository:
   git clone https://github.com/username/pos_desktop.git
2. Navigate to the project folder:
  cd pos_desktop
3. Get dependencies:
  flutter pub get
4. Run the application on Windows:
  flutter run -d windows

## Usage

  - Launch the application.

  - Add categories and products if the database is empty.

  - Start adding products to the cart using either the barcode reader or the product grid.

  - Generate invoices and reports directly from the interface.

## Tech Stack

  - Flutter: Modern UI and cross-platform capabilities

  - SQLite: Local database for offline storage

  - Dart: Programming language for application logic
