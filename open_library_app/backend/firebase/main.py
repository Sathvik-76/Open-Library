from fastapi import FastAPI, HTTPException, Request
from pydantic import BaseModel
from datetime import datetime
import os
import firebase_admin
from firebase_admin import firestore
from firebase_admin import credentials, initialize_app
from dotenv import load_dotenv
load_dotenv()


firebase_key_path = os.getenv("GOOGLE_APPLICATION_CREDENTIALS", "serviceAccountKey.json")

if not firebase_admin._apps:
    cred = credentials.Certificate(firebase_key_path)
    initialize_app(cred)


db = firestore.client()
app = FastAPI()

#  Models
class BookLoanRequest(BaseModel):
    mobile_no: int           # Mobile number to find the user
    book_id: str             # This is now ISBN, not document ID
    metro_id: int            # Metro station ID

class BookReturnRequest(BaseModel):
    mobile_no: int
    book_id: str   # This is the book ISBN
    metro_id: int
@app.get("/user_loans/{mobile_no}")
def get_user_loans(mobile_no: str):
    try:
        print(f"[DEBUG] Fetching user with mobile number: {mobile_no}")
        user_query = db.collection("Users").where("usr_mob_no", "==", int(mobile_no)).limit(1).get()

        if not user_query:
            raise HTTPException(status_code=404, detail="User not found")

        user_doc = user_query[0]
        user_ref_path = user_doc.reference.path
        print(f"[DEBUG] User ID: {user_doc.id}, Path: {user_ref_path}")

        print("[DEBUG] Fetching all active loans...")
        loan_query = db.collection("Book_lnr") \
            .where("status", "==", "Loaned") \
            .where("bk_lnr_return_dt", "==", None) \
            .stream()

        loans = []
        for doc in loan_query:
            loan_data = doc.to_dict()
            loan_user_ref = loan_data.get("bk_lnr_loaned_usr_id")
            if loan_user_ref and loan_user_ref.path == user_ref_path:
                book_ref = loan_data.get("bk_lnr_loaned_bk_id")
                book_isbn = None
                if book_ref:
                    try:
                        book_doc = book_ref.get()
                        if book_doc.exists:
                            book_isbn = book_doc.to_dict().get("bk_isbn")
                    except Exception as e:
                        print(f"[WARN] Failed to fetch book for loan {doc.id}: {e}")

                loans.append({
                    # For Flutter UI
                    "book_title": loan_data.get("bk_title", "Untitled"),
                    "book_id": book_ref.id if book_ref else None,
                    "book_isbn": book_isbn,  #  added
                    "metro_name": loan_data.get("picked_at_metro_name", ""),
                    "metro_id": loan_data.get("picked_at_metro_id", -1),
                    "loan_time": loan_data.get("bk_lnr_loaned_dt").isoformat() if loan_data.get("bk_lnr_loaned_dt") else None,
                    "status": loan_data.get("status", "Unknown"),

                    # Extra metadata
                    "loan_id": doc.id,
                    "usr_name": loan_data.get("usr_name"),
                    "processed_by": loan_data.get("processed_by"),
                    "loan_ref_path": doc.reference.path,
                    "dropped_at_metro_id": loan_data.get("dropped_at_metro_id"),
                    "dropped_at_metro_name": loan_data.get("dropped_at_metro_name"),
                })


        return {"loans": loans}

    except Exception as e:
        print("[ERROR] Exception in /user_loans:", str(e))
        raise HTTPException(status_code=500, detail="Internal Server Error")


@app.post("/return_book")
async def return_book(request: BookReturnRequest):
    try:
        print("Step 1: Fetching user...")
        user_query = db.collection("Users").where("usr_mob_no", "==", request.mobile_no).limit(1).get()
        if not user_query:
            raise HTTPException(status_code=404, detail="User not found")
        user_doc = user_query[0]
        user_ref = user_doc.reference
        user_data = user_doc.to_dict()

        print("Step 2: Fetching book by ISBN...")
        book_query = db.collection("Books").where("bk_isbn", "==", request.book_id).limit(1).get()
        if not book_query:
            raise HTTPException(status_code=404, detail="Book not found")
        book_doc = book_query[0]
        book_ref = book_doc.reference
        book_data = book_doc.to_dict()

        print("Step 3: Fetching metro station...")
        metro_query = db.collection("metro_stations").where("mtr_id", "==", request.metro_id).limit(1).get()
        if not metro_query:
            raise HTTPException(status_code=404, detail="Metro station ID not found")
        metro_data = metro_query[0].to_dict()

        print("Step 4: Finding active loan record...")
        loan_query = db.collection("Book_lnr") \
            .where("bk_lnr_loaned_bk_id", "==", book_ref) \
            .where("bk_lnr_loaned_usr_id", "==", user_ref) \
            .where("status", "==", "Loaned") \
            .where("bk_lnr_return_dt", "==", None) \
            .limit(1).get()

        if not loan_query:
            raise HTTPException(status_code=400, detail="No active loan found for this user and book")

        loan_doc = loan_query[0].reference

        print("Step 5: Marking loan as returned...")
        loan_doc.update({
            "bk_lnr_return_dt": datetime.utcnow(),
            "status": "Returned",
            "dropped_at_metro_id": request.metro_id,
            "dropped_at_metro_name": metro_data.get("mtr_name", ""),
        })

        print("Step 6: Marking book as available again...")
        book_ref.update({"bk_avlbl": True})

        return {
            "message": f"Book '{book_data.get('bk_title')}' returned by {user_data.get('usr_name')} at metro {metro_data.get('mtr_name')}"
        }

    except Exception as e:
        print("Error in /return_book:", e)
        raise HTTPException(status_code=500, detail=str(e))
#  User Registration
# @app.post("/register")
# async def register_user(request: Request):
#     data = await request.json()
#     phone = data.get("usr_mob_no")
#     email = data.get("usr_email_id")

#     existing_mobile = db.collection("Users").where("usr_mob_no", "==", phone).limit(1).get()
#     if existing_mobile:
#         return {"error": "Mobile number already registered"}

#     existing_email = db.collection("Users").where("usr_email_id", "==", email).limit(1).get()
#     if existing_email:
#         return {"error": "Email already registered"}

#     data["usr_created_on"] = datetime.utcnow()
#     data["usr_updated_on"] = datetime.utcnow()
#     data["usr_status"] = "Active"
#     db.collection("Users").add(data)

#     return {"message": "User registered successfully"}


#  Login
# @app.post("/login")
# async def login_user(request: Request):
#     data = await request.json()
#     phone = data.get("mobile")
#     password = data.get("password")

#     user_query = db.collection("Users").where("usr_mob_no", "==", phone).limit(1).get()
#     if not user_query:
#         return {"error": "User not found"}

#     user_data = user_query[0].to_dict()
#     if user_data.get("password") != password:
#         return {"error": "Incorrect password"}

#     return {"message": "Login successful"}


#  Loan a Book using ISBN
@app.post("/loan_book")
def loan_book(request: BookLoanRequest):
    try:
        print("Step 1: Fetching user by mobile...")
        user_query = db.collection("Users").where("usr_mob_no", "==", request.mobile_no).limit(1).get()
        if not user_query:
            raise HTTPException(status_code=404, detail="User not found")
        user_doc = user_query[0]
        user_data = user_doc.to_dict()
        user_id = user_doc.id

        print("Step 2: Validating book by ISBN...")
        book_query = db.collection("Books").where("bk_isbn", "==", request.book_id).limit(1).get()
        if not book_query:
            raise HTTPException(status_code=404, detail="Book not found")
        book_doc = book_query[0]
        book_data = book_doc.to_dict()
        book_ref = book_doc.reference

        if not book_data.get("bk_avlbl", True):
            raise HTTPException(status_code=409, detail="Book is already loaned")

        print("Step 3: Validating metro station...")
        metro_query = db.collection("metro_stations").where("mtr_id", "==", request.metro_id).limit(1).get()
        if not metro_query:
            raise HTTPException(status_code=404, detail="Metro station not found")
        metro_data = metro_query[0].to_dict()

        print("Step 4: Checking existing loan...")
        loan_check = db.collection("Book_lnr") \
            .where("bk_lnr_loaned_bk_id", "==", book_ref) \
            .where("status", "==", "Loaned") \
            .where("bk_lnr_return_dt", "==", None) \
            .limit(1).get()
        if loan_check:
            raise HTTPException(status_code=409, detail="Book is already loaned out")

        print("Step 5: Creating loan record...")
        db.collection("Book_lnr").add({
            "bk_lnr_loaned_usr_id": db.collection("Users").document(user_id),
            "bk_lnr_loaned_bk_id": book_ref,
            "usr_name": user_data.get("usr_name", ""),
            "bk_title": book_data.get("bk_title", ""),
            "picked_at_metro_id": request.metro_id,
            "picked_at_metro_name": metro_data.get("mtr_name", ""),
            "status": "Loaned",
            "bk_lnr_loaned_dt": datetime.utcnow(),
            "bk_lnr_aging": 0,
            "processed_by": "System",
            "bk_lnr_return_dt": None,
            "dropped_at_metro_id": -1,
            "dropped_at_metro_name": ""
        })

        print("Step 6: Marking book as unavailable...")
        book_ref.update({"bk_avlbl": False})

        return {
            "message": f"Book '{book_data.get('bk_title')}' loaned successfully by {user_data.get('usr_name')} from metro {metro_data.get('mtr_name')}"
        }

    except Exception as e:
        print("Error in /loan_book:", e)
        raise HTTPException(status_code=500, detail=str(e))


#  Return Book by ISBN
@app.post("/return")
async def return_book(request: Request):
    data = await request.json()

    book_query = db.collection("Books").where("bk_isbn", "==", data["book_id"]).limit(1).get()
    if not book_query:
        return {"error": "Book not found"}
    book_doc = book_query[0]
    book_ref = book_doc.reference

    return_book_query = db.collection("Book_lnr") \
        .where("bk_lnr_loaned_bk_id", "==", book_ref) \
        .where("status", "==", "Loaned") \
        .limit(1).get()

    if not return_book_query:
        return {"error": "No active loan found"}

    loan_doc = return_book_query[0].reference
    loan_doc.update({
        "bk_lnr_return_dt": datetime.utcnow(),
        "status": "Returned",
        "dropped_at_metro_id": data.get("metro_id", -1),
        "dropped_at_metro_name": data.get("metro_name", ""),
    })

    book_ref.update({"bk_avlbl": True})
    return {"message": "Book returned successfully"}


# 📦 View Active Loans by Mobile Number
@app.get("/active_loans/{mobile}")
def active_loans(mobile: str):
    loan_query = db.collection("Book_lnr") \
        .where("bk_lnr_loaned_usr_id", "!=", None) \
        .where("status", "==", "Loaned") \
        .stream()

    loans = []
    for loan in loan_query:
        loan_data = loan.to_dict()
        user_ref = loan_data.get("bk_lnr_loaned_usr_id")
        if user_ref:
            user_doc = user_ref.get()
            if user_doc.exists and user_doc.to_dict().get("usr_mob_no") == int(mobile):
                loans.append(loan_data)

    return {"loans": loans}
@app.get("/metro_stations")
def get_metro_stations():
    try:
        stations = db.collection("metro_stations").stream()
        result = []
        for s in stations:
            d = s.to_dict()
            result.append({
                "mtr_id": d.get("mtr_id"),
                "mtr_name": d.get("mtr_name")
            })
        return result
    except Exception as e:
        print("[ERROR] in /metro_stations:", e)
        raise HTTPException(status_code=500, detail="Could not fetch metro stations")



