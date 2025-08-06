# ✅ Place your full FastAPI app with all endpoints here
from fastapi import FastAPI, HTTPException, Depends, status
from fastapi.security import OAuth2PasswordBearer, OAuth2PasswordRequestForm
from pydantic import BaseModel
from typing import Optional
from datetime import datetime, timedelta
import posgress_backend_reference.db_access as db_access
from jose import JWTError, jwt
import os
from fastapi.middleware.cors import CORSMiddleware

# --- FastAPI App Initialization ---
app = FastAPI(
    title="OpenLibrary Backend - Full Project",
    description="Backend API for managing books, users, and loans in Metro stations with Authentication.",
    version="0.0.1",
)

# # --- JWT Config ---
# SECRET_KEY = os.getenv("SECRET_KEY", "your-super-secret-key-that-no-one-can-guess")
# ALGORITHM = "HS256"
# ACCESS_TOKEN_EXPIRE_MINUTES = 30

# oauth2_scheme = OAuth2PasswordBearer(tokenUrl="token")

# --- Models ---
class Token(BaseModel):
    access_token: str
    token_type: str

class TokenData(BaseModel):
    user_id: Optional[int] = None
    mobile_no: Optional[str] = None

class UserLogin(BaseModel):
    mobile_no: str
    password: str

class UserRegister(BaseModel):
    mobile_no: str
    name: str
    password: str
    email: Optional[str] = None

class UserResponse(BaseModel):
    user_id: int
    mobile_no: str
    user_name: str
    email: Optional[str] = None
    class Config:
        from_attributes = True

class BookAction(BaseModel):
    book_id: int
    metro_id: int

class BookLoanRequest(BaseModel):
    mobile_no: str
    book_id: int
    metro_id: int

class BookReturnRequest(BaseModel):
    mobile_no: str
    book_id: int
    metro_id: int

# --- JWT Utils ---
def create_access_token(data: dict, expires_delta: Optional[timedelta] = None):
    to_encode = data.copy()
    expire = datetime.utcnow() + (expires_delta or timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES))
    to_encode.update({"exp": expire})
    return jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)

async def get_current_user(token: str = Depends(oauth2_scheme)):
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        user_id = payload.get("user_id")
        mobile_no = payload.get("mobile_no")
        if user_id is None or mobile_no is None:
            raise credentials_exception
        return TokenData(user_id=user_id, mobile_no=mobile_no)
    except JWTError:
        raise credentials_exception

# --- CORS ---
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# --- API Routes ---
@app.get("/")
def root():
    return {"message": "OpenLibrary Backend is running"}

@app.post("/register", response_model=UserResponse)
async def register_user(user: UserRegister):
    user_id = db_access.register_user_db(user.mobile_no, user.name, user.password, user.email)
    if user_id == -1:
        raise HTTPException(status_code=409, detail="Mobile number already registered.")
    elif user_id is None:
        raise HTTPException(status_code=500, detail="Failed to register user.")
    return UserResponse(user_id=user_id, mobile_no=user.mobile_no, user_name=user.name, email=user.email)

@app.post("/token", response_model=Token)
async def login_for_access_token(form_data: OAuth2PasswordRequestForm = Depends()):
    user_data = db_access.get_user_by_mobile_db(form_data.username)
    if not user_data or not db_access.verify_password(form_data.password, user_data["hashed_password"]):
        raise HTTPException(status_code=401, detail="Invalid credentials")
    access_token = create_access_token(data={"user_id": user_data["user_id"], "mobile_no": user_data["mobile_no"]})
    return {"access_token": access_token, "token_type": "bearer"}

@app.get("/check_file")
def check_file():
    return {"file": __file__}
# Add this temporarily to main.py

@app.post("/loan_book")
async def loan_book(request: BookLoanRequest):
    # 1. Validate user
    user = db_access.get_user_by_mobile_db(request.mobile_no)
    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    # 2. Validate book ID
    if not db_access.is_valid_book_id(request.book_id):
        raise HTTPException(status_code=404, detail="Book ID not found")

    # 3. Validate metro ID
    if not db_access.is_valid_metro_id(request.metro_id):
        raise HTTPException(status_code=404, detail="Metro station ID not found")

    # 4. Check if the book is already loaned out (regardless of metro)
    if db_access.is_book_already_loaned(request.book_id):
        raise HTTPException(status_code=409, detail="Book is already loaned out")

    # 5. Proceed with loan
    result = db_access.loan_book_db(user["user_id"], request.book_id, request.metro_id)
    if not result["success"]:
        raise HTTPException(status_code=500, detail=result["reason"])

    return {
        "message": f"Book {request.book_id} successfully loaned by user {user['user_id']} from metro {request.metro_id}"
    }

# @app.post("/return_book")
# async def return_book(action: BookAction, current_user: TokenData = Depends(get_current_user)):
#     # 1. Validate book ID
#     if not db_access.is_valid_book_id(action.book_id):
#         raise HTTPException(status_code=404, detail="Book ID not found")

#     # 2. Validate metro ID
#     if not db_access.is_valid_metro_id(action.metro_id):
#         raise HTTPException(status_code=404, detail="Metro station ID not found")

#     # 3. Attempt to return book
#     result = db_access.return_book_db(current_user.user_id, action.book_id, action.metro_id)
#     if not result["success"]:
#         raise HTTPException(status_code=400, detail=result["reason"])

#     return {
#         "message": f"Book {action.book_id} returned by user {current_user.user_id} to metro {action.metro_id}"
#     }

#changed temporily to use request model....dont uncomment the above code

@app.post("/return_book")
async def return_book(request: BookReturnRequest):
    # 1. Validate user
    user = db_access.get_user_by_mobile_db(request.mobile_no)
    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    # 2. Validate book ID
    if not db_access.is_valid_book_id(request.book_id):
        raise HTTPException(status_code=404, detail="Book ID not found")

    # 3. Validate metro ID
    if not db_access.is_valid_metro_id(request.metro_id):
        raise HTTPException(status_code=404, detail="Metro station ID not found")

    # 4. Attempt to return book
    result = db_access.return_book_db(user["user_id"], request.book_id, request.metro_id)
    if not result["success"]:
        raise HTTPException(status_code=400, detail=result["reason"])

    return {
        "message": f"Book {request.book_id} returned by user {user['user_id']} to metro {request.metro_id}"
    }

# --- NEW ENDPOINT: User active loans ---
@app.get("/user_loans/{mobile_no}")
async def get_user_loans(mobile_no: str):
    # 1. Get user ID from mobile number
    user = db_access.get_user_by_mobile_db(mobile_no)
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    user_id = user["user_id"]

    # 2. Fetch active book loans (not yet returned)
    loans = db_access.get_active_loans_by_user(user_id)

    return {"loans": loans}

