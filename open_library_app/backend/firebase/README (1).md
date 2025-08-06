# 📚 Metro Book Loan API

A FastAPI backend integrated with Firebase Firestore to manage user registrations, book loans, returns, and metro station tracking for a distributed library system.

Note: Make sure you are inside backend/firebase 
for running flutter app in mobile device run your backend using this command
uvicorn main:app --host 0.0.0.0 --port 8000

if on emulator use this
uvicorn main:app --reload
---

## 🚀 Features

-  User registration & login with phone and email
-  Loan and return books using ISBN
-  Track loan activity across metro stations
-  Secure Firebase Admin SDK initialization
-  View active loans for users
-  Get list of metro stations

---

## 🛠️ Technologies Used

- **Python 3.10+**
- **FastAPI** – Lightweight, high-performance web framework
- **Firebase Admin SDK** – Backend integration with Firebase services
- **Google Cloud Firestore** – NoSQL database
- **Uvicorn** – ASGI server for running FastAPI

---

## 📁 Folder Structure

```
📦project-root/
 ┣ 📄main.py               # FastAPI app
 ┣ 📄serviceAccountKey.json # Firebase Admin SDK credentials
 ┣ 📄requirements.txt      # Python dependencies
 ┗ 📄README.md             # This documentation
```

---

## 📦 Installation

### 1. Clone the repository

```bash
git clone https://github.com/Sharika999/Open_Lib.git
cd backend/firebase
```

### 2. Install dependencies

```bash
pip install -r requirements.txt
```

### 3. Add Firebase credentials

Place your Firebase service account key in the root directory as:

```
serviceAccountKey.json
```

> ⚠️ Never commit this file to public repositories!

---

## ▶️ Running the API

```bash
uvicorn main:app --reload
```

- Server will run at `http://127.0.0.1:8000`
- Interactive API docs available at `http://127.0.0.1:8000/docs`

---

## 📚 API Endpoints

### 📌 Authentication

- `handled by firebase  – Register a new user (phone & email)
- `handled by firebase – Log in user by phone and password

### 📌 Book Loan Management

- `POST /loan_book` – Loan a book using mobile number and ISBN
- `POST /return_book` – Return a book using mobile number and ISBN
- `POST /return` – Alternate return method (with metro info)
- `GET /user_loans/{mobile_no}` – View all loans of a user
- `GET /active_loans/{mobile}` – View currently loaned books for user

### 📌 Metro Stations

- `GET /metro_stations` – Retrieve list of available metro stations

---

## 📘 Example Book Loan Request

```json
POST /loan_book

{
  "mobile_no": 9876543210,
  "book_id": "9781234567890",
  "metro_id": 101
}
```

---

## ✅ Sample Firestore Structure

### `Users` Collection:
```json
{
  "usr_name": "Alice",
  "usr_email_id": "alice@example.com",
  "usr_mob_no": 9876543210,
  "password": "Secure123"
}
```

### `Books` Collection:
```json
{
  "bk_title": "Atomic Habits",
  "bk_isbn": "9781234567890",
  "bk_avlbl": true
}
```

### `Book_lnr` Collection (Loans):
```json
{
  "bk_lnr_loaned_usr_id": [UserRef],
  "bk_lnr_loaned_bk_id": [BookRef],
  "bk_lnr_loaned_dt": [timestamp],
  "status": "Loaned",
  ...
}
```

### `metro_stations` Collection:
```json
{
  "mtr_id": 101,
  "mtr_name": "Central Metro Station"
}
```

---

## 🧪 Testing & Debugging

- Use [http://127.0.0.1:8000/docs](http://127.0.0.1:8000/docs) to test endpoints via Swagger UI
- Add `print()` statements or logging for server-side debugging
- Use Postman or cURL for advanced API testing

---

## 🧰 Postman Collection or else test on FastAPI docs

Import the provided Postman Collection JSON (`postman_collection.json`) into [Postman](https://www.postman.com/downloads/) to test all endpoints easily.

- Supports `/loan_book`, `/return_book`, `/metro_stations`, etc.
- Pre-filled request bodies
- Easy way to test with local or hosted URL

---

## 🛡️ Security Notes

- Use environment variables to load sensitive data in production
- Enable Firebase Authentication for advanced user management
- Hash passwords before storing them
- Limit Firestore access using Firestore Security Rules

---

## 📄 License

MIT License © 2025 Your Name