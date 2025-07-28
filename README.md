# 🗄️  BashDBMS: A Pure Bash Database Management System

Welcome to **BashDBMS** – a fully interactive, menu-driven Database Management System built entirely in Bash!  
This project is a showcase of advanced Bash scripting, simulating core SQL-like database operations, complete with a modern TUI (Terminal User Interface) powered by `fzf`, robust logging, and automated testing.

---

## 🎬 Demo

 https://github.com/user-attachments/assets/dbe991bd-81fe-43bb-bd73-ecc9323d265d

---

## ✨ Features

- **Database Management**
  - Create, drop, and list databases
  - Connect to any database interactively

- **Table Management**
  - Create tables with rich metadata (column name, type, primary key, nullability)
  - Drop and list tables
  - View table structure and metadata

- **Data Manipulation**
  - Insert validated rows (type, nullability, primary key)
  - Update and delete rows with filter support

- **Data Querying (DQL)**
  - Powerful filter mode: select any field, choose an operator (`=`, `!=`, `>`, `<`, `>=`, `<=`), and filter by value
  - Chain multiple filters for complex queries
  - Update or delete filtered results
  - Reset filters at any time

- **Interactive UI**
  - All menus and selections are powered by `fzf` for a modern, user-friendly CLI experience
  - Real-time log preview in menus

- **Logging System**
  - All actions and errors are timestamped and logged to `logs/dbms.log`
  - Color-coded log preview in the UI

- **Testing**
  - Automated unit tests using `bats` for validation and DDL logic

---

## 🗂️ Project Structure

```
DBMS_bash/
├── core/           # Main operation scripts (DDL, DML, DQL)
│   ├── ddl_dbms.sh
│   ├── dml_dbms.sh
│   └── dql_dbms.sh
│
├── lib/            # Core logic and utilities
│   ├── ddl_operations.sh
│   ├── dml_operations.sh
│   ├── dql_operations.sh
│   ├── validation.sh
│   └── log.sh
│
├── database/       # All databases and tables (plain text files)
│   └── <db_name>/
│       ├── <table_name>        # Data file (rows)
│       └── <table_name>.meta   # Metadata file for table columns
│
├── logs/
│   └── dbms.log    # System logs
│
├── temp/           # Temporary files for filtered views, etc.
│
├── test/           # Automated tests (bats)
│   ├── test_ddl_operations.bats
│   └── test_validation.bats
│
└── main.sh         # Entry point script
```

---

## 🛠️ Prerequisites

- **Bash** (v4+ recommended)
- **fzf** (for interactive menus)
- **bats** (for running tests)

Install dependencies on Ubuntu/Debian:
```bash
sudo apt update
sudo apt install fzf bats
```

---

## 🚦 Getting Started

1. **Clone the repository:**
   ```bash
   git clone <your-repo-url>
   cd DBMS_bash
   ```

2. **Run the main script:**
   ```bash
   bash main.sh
   ```

3. **Follow the interactive menus** to manage databases, tables, and data!

---

## 🧑‍💻 Usage Highlights

- **Create a Database:**  
  Use the menu to create a new database. Each database is a directory under `database/`.

- **Create a Table:**  
  Define columns, types (`int` or `string`), primary key, and nullability. Metadata is stored in `<table_name>.meta`.

- **Insert Data:**  
  All inputs are validated for type, nullability, and primary key uniqueness.

- **Filter Data:**  
  - Select a field, choose an operator (`=`, `!=`, `>`, `<`, `>=`, `<=`), and enter a value.
  - Chain multiple filters for advanced queries.
  - Update or delete filtered rows directly.

- **Logging:**  
  All actions are logged with timestamps. View logs in real-time from the UI.

- **Testing:**  
  Run all tests with:
  ```bash
  bats test/
  ```

---

## 🧪 Validation & Constraints

- **Data Types:**  
  Only valid integers or strings are accepted per column definition.

- **Nullability:**  
  Non-nullable fields must be filled.

- **Primary Key:**  
  Uniqueness is enforced for primary key columns.

- **Input Format:**  
  All user inputs are validated for correctness and safety.

---

## 🏗️ Architecture

- **Modular Design:**  
  - `core/` scripts handle user interaction and high-level flow.
  - `lib/` scripts implement the actual logic for DDL, DML, DQL, validation, and logging.

- **Plain Text Storage:**  
  - Each table is a text file; each row is a line.
  - Metadata is stored in a `.meta` file per table.

- **Temporary Filtering:**  
  - Filtered results are stored in `temp/` for further operations (update, delete, reset).

---

## 📝 Logging System

- All actions, warnings, and errors are logged to `logs/dbms.log`.
- Log entries are timestamped and color-coded in the UI for clarity.
- Log preview is available in all interactive menus.

---

## 🧪 Testing

- **Automated tests** are written using `bats` and cover:
  - Validation logic
  - DDL operations
- To run all tests:
  ```bash
  bats test/
  ```

---

## 💡 Future Improvements

- Export/import databases
- Advanced filtering syntax (e.g., `column > 20`)
- Sorting and table joins
- User authentication and access control
- Enhanced error handling and reporting

---

## 🤝 Contributing

Contributions, bug reports, and feature requests are welcome!  
Please open an issue or submit a pull request.

---

## 📝 License

This project is for educational purposes and is open source.

---

## 🙏 Acknowledgments

- **Information Technology Institute (ITI)** – for the Bash Scripting course inspiration
- The open-source community for `fzf` and `bats`

---

**Enjoy managing your data the Bash way!**