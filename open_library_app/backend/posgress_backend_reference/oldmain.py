# Library/backend/main.py
from fastapi import FastAPI, HTTPException, Depends, status
from fastapi.security import OAuth2PasswordBearer, OAuth2PasswordRequestForm # New imports
from pydantic import BaseModel
from typing import Optional
from datetime import datetime, timedelta
import db_access # Import your db_access.py
from jose import JWTError, jwt # New imports
import os # To get environment variables for SECRET_KEY

# --- FastAPI App Initialization ---
app = FastAPI(
    title="OpenLibrary Backend - Full Project",
    description="Backend API for managing books, users, and loans in Metro stations with Authentication.",
    version="0.0.1",
)

# --- JWT Configuration (IMPORTANT: In a real app, use environment variables) ---
# For POC, hardcode. For production, get from environment variables (e.g., os.environ.get("SECRET_KEY"))
# You MUST change this secret key to a long, random string in a real application!
SECRET_KEY = os.getenv("SECRET_KEY", "your-super-secret-key-that-no-one-can-guess-replace-this-now")
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 30 # Token validity period

# OAuth2 scheme for dependency injection
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="token") # tokenUrl is the endpoint where client gets token

# --- Pydantic Models for Request/Response Data (New & Modified) ---

# Authentication related models
class Token(BaseModel):
    access_token: str
    token_type: str

class TokenData(BaseModel):
    user_id: Optional[int] = None
    mobile_no: Optional[str] = None

class UserLogin(BaseModel):
    mobile_no: str
    password: str

# User related models
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
        from_attributes = True # Allows conversion from ORM objects/dictionaries

# Book action related models (already existing but good to re-state)
class BookAction(BaseModel):
    book_id: int
    metro_id: int # This will be the picked_at or dropped_at location


# --- JWT Utility Functions ---

def create_access_token(data: dict, expires_delta: Optional[timedelta] = None):
    to_encode = data.copy()
    if expires_delta:
        expire = datetime.utcnow() + expires_delta
    else:
        expire = datetime.utcnow() + timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    to_encode.update({"exp": expire})
    encoded_jwt = jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)
    return encoded_jwt

async def get_current_user(token: str = Depends(oauth2_scheme)):
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        user_id: int = payload.get("user_id")
        mobile_no: str = payload.get("mobile_no")
        if user_id is None or mobile_no is None:
            raise credentials_exception
        token_data = TokenData(user_id=user_id, mobile_no=mobile_no)
    except JWTError:
        raise credentials_exception
    # In a real app, you'd fetch the user from DB to ensure they still exist and are active
    # For now, we return TokenData directly
    return token_data


# --- API Endpoints ---

@app.post("/register", response_model=UserResponse, summary="Register a new user")
async def register_user(user: UserRegister):
    """
    Registers a new user in the system.
    Returns the newly created user_id and other details.
    """
    user_id = db_access.register_user_db(user.mobile_no, user.name, user.password, user.email)
    if user_id == -1:
        raise HTTPException(status_code=409, detail="Mobile number already registered.")
    elif user_id is None:
        raise HTTPException(status_code=500, detail="Failed to register user due to a database error.")

    # Fetch newly registered user to return as UserResponse model
    # (assuming db_access.register_user_db returns user_id, mobile_no, user_name, email)
    # In a real app, you might re-fetch full user details from DB after registration
    # For simplicity, we construct the UserResponse from the request and returned ID.
    return UserResponse(user_id=user_id, mobile_no=user.mobile_no, user_name=user.name, email=user.email)

@app.post("/token", response_model=Token, summary="Authenticate user and get access token")
async def login_for_access_token(form_data: OAuth2PasswordRequestForm = Depends()):
    """
    Authenticates a user with mobile_no and password,
    and returns an access token if credentials are valid.
    """
    user_data = db_access.get_user_by_mobile_db(form_data.username) # form_data.username is the mobile_no
    if not user_data:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect mobile number or password",
            headers={"WWW-Authenticate": "Bearer"},
        )
    if not db_access.verify_password(form_data.password, user_data["hashed_password"]):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect mobile number or password",
            headers={"WWW-Authenticate": "Bearer"},
        )

    # If authentication successful, create an access token
    access_token_expires = timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    access_token = create_access_token(
        data={"user_id": user_data["user_id"], "mobile_no": user_data["mobile_no"]},
        expires_delta=access_token_expires
    )
    return {"access_token": access_token, "token_type": "bearer"}


@app.post("/loan_book", summary="Record a book being taken/loaned (Protected)")
async def loan_book(action: BookAction, current_user: TokenData = Depends(get_current_user)):
    """
    Records that an authenticated user has taken a book from a specific metro station.
    Updates book's current location and loan history.
    Requires authentication token.
    """
    # Use current_user.user_id for the loan action, ensuring it's the authenticated user
    success = db_access.loan_book_db(current_user.user_id, action.book_id, action.metro_id)
    if not success:
        raise HTTPException(status_code=500, detail="Failed to record book loan.")
    return {"message": f"Book {action.book_id} loaned by user {current_user.user_id} from metro {action.metro_id}"}


@app.post("/return_book", summary="Record a book being deposited/returned (Protected)")
async def return_book(action: BookAction, current_user: TokenData = Depends(get_current_user)):
    """
    Records that an authenticated user has returned a book to a specific metro station.
    Updates book's current location and loan history.
    Requires authentication token.
    """
    # Use current_user.user_id for the return action
    success = db_access.return_book_db(current_user.user_id, action.book_id, action.metro_id)
    if not success:
        raise HTTPException(status_code=500, detail="Failed to record book return or no active loan found for this user/book.")
    return {"message": f"Book {action.book_id} returned by user {current_user.user_id} to metro {action.metro_id}"}

@app.get("/", summary="Root endpoint for health check")
async def root():
    """
    A simple health check endpoint.
    """
    return {"message": "OpenLibrary Backend is running!"}