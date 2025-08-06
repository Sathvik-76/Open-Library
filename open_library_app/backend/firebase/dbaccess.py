import firebase_admin
from firebase_admin import credentials, firestore

cred = credentials.Certificate("serviceAccountKey.json")
firebase_admin.initialize_app(cred)

db = firestore.client()
from google.cloud import firestore
from datetime import datetime

db = firestore.Client()

def loan_book_firestore(user_id: str, book_id: str, metro_id: int):
    try:
        # 1. Validate book exists and is available
        book_ref = db.collection("Books").document(book_id)
        book_doc = book_ref.get()
        if not book_doc.exists:
            return {"success": False, "reason": "Book does not exist"}

        if not book_doc.get("bk_avlbl", True):
            return {"success": False, "reason": "Book is already loaned out"}

        # 2. Validate metro station exists
        metro_query = db.collection("metro_stations").where("mtr_id", "==", metro_id).limit(1).get()
        if not metro_query:
            return {"success": False, "reason": "Invalid Metro Station ID"}
        metro_doc = metro_query[0]
        metro_name = metro_doc.get("mtr_name")

        # 3. Validate user exists
        user_ref = db.collection("Users").document(user_id)
        user_doc = user_ref.get()
        if not user_doc.exists:
            return {"success": False, "reason": "User does not exist"}

        usr_name = user_doc.get("usr_name")

        # 4. Proceed to log the loan
        book_lnr_data = {
            "bk_lnr_loaned_usr_id": user_ref,
            "bk_lnr_loaned_bk_id": book_ref,
            "usr_name": usr_name,
            "bk_title": book_doc.get("bk_title"),
            "picked_at_metro_id": metro_id,
            "picked_at_metro_name": metro_name,
            "dropped_at_metro_id": -1,
            "dropped_at_metro_name": "",
            "status": "Loaned",
            "bk_lnr_loaned_dt": datetime.utcnow(),
            "bk_lnr_return_dt": None,
            "processed_by": "System",
            "bk_lnr_aging": 0,
        }

        db.collection("Book_lnr").add(book_lnr_data)

        # 5. Update book availability
        book_ref.update({"bk_avlbl": False})

        return {"success": True}

    except Exception as e:
        print("Firestore Error in loan_book_firestore:", e)
        return {"success": False, "reason": "Backend error"}


def register_user_db(user_data):
    phone = user_data.get("mobile")
    user_doc = db.collection("Users").document(phone)
    if user_doc.get().exists:
        return {"error": "User already exists"}
    user_doc.set(user_data)
    return {"message": "User registered successfully"}

def login_user_db(mobile, password):
    user_ref = db.collection("Users").document(mobile)
    user = user_ref.get()
    if not user.exists:
        return {"error": "User not found"}
    user_data = user.to_dict()
    if user_data.get("password") != password:
        return {"error": "Incorrect password"}
    return {"message": "Login successful"}

def loan_book_db(mobile, book_id, metro_id):
    doc_id = f"{mobile}_{book_id}"
    existing = db.collection("book_lnr").document(doc_id).get()
    if existing.exists:
        return {"error": "Book already loaned"}
    db.collection("book_lnr").document(doc_id).set({
        "mobile": mobile,
        "book_id": book_id,
        "metro_id": metro_id,
        "status": "active"
    })
    return {"message": "Book loaned successfully"}

def return_book_db(mobile, book_id):
    doc_id = f"{mobile}_{book_id}"
    loan_doc = db.collection("book_lnr").document(doc_id)
    if not loan_doc.get().exists:
        return {"error": "Loan not found"}
    loan_doc.update({"status": "returned"})
    return {"message": "Book returned successfully"}

def get_active_loans_db(mobile):
    query = db.collection("book_lnr").where("mobile", "==", mobile).where("status", "==", "active").stream()
    loans = [doc.to_dict() for doc in query]
    return {"loans": loans}
