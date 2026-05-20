from fastapi import FastAPI, HTTPException, Depends
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from pydantic import BaseModel, EmailStr
from datetime import datetime, timedelta
from dotenv import load_dotenv
import mysql.connector
import bcrypt
import jwt
import secrets
import requests
import os

# =========================
# ENV 로드
# =========================

load_dotenv()

ACCESS_SECRET_KEY = os.getenv("ACCESS_SECRET_KEY")
REFRESH_SECRET_KEY = os.getenv("REFRESH_SECRET_KEY")
GOOGLE_CLIENT_ID = os.getenv("GOOGLE_CLIENT_ID")

DB_CONFIG = {
    "host": os.getenv("DB_HOST"),
    "user": os.getenv("DB_USER"),
    "password": os.getenv("DB_PASSWORD"),
    "database": os.getenv("DB_NAME"),
}

ALGORITHM = "HS256"
ACCESS_EXPIRE_MINUTES = 15
REFRESH_EXPIRE_DAYS = 14

app = FastAPI()
security = HTTPBearer()

# =========================
# DB 연결
# =========================

def get_db():
    return mysql.connector.connect(**DB_CONFIG)

# =========================
# Pydantic 모델
# =========================

class RegisterModel(BaseModel):
    email: EmailStr
    password: str

class LoginModel(BaseModel):
    email: EmailStr
    password: str

class RefreshModel(BaseModel):
    refresh_token: str

class GoogleLoginModel(BaseModel):
    id_token: str

# =========================
# JWT 생성
# =========================

def create_access_token(user_id: int):
    expire = datetime.utcnow() + timedelta(minutes=ACCESS_EXPIRE_MINUTES)
    payload = {"sub": str(user_id), "exp": expire}
    return jwt.encode(payload, ACCESS_SECRET_KEY, algorithm=ALGORITHM)

def create_refresh_token(user_id: int):
    expire = datetime.utcnow() + timedelta(days=REFRESH_EXPIRE_DAYS)
    payload = {
        "sub": str(user_id),
        "exp": expire,
        "jti": secrets.token_hex(16)
    }
    token = jwt.encode(payload, REFRESH_SECRET_KEY, algorithm=ALGORITHM)
    return token, expire

# =========================
# 회원가입
# =========================

@app.post("/auth/register")
def register(data: RegisterModel):
    conn = get_db()
    cursor = conn.cursor(dictionary=True)

    try:
        cursor.execute("SELECT id FROM users WHERE email=%s", (data.email,))
        if cursor.fetchone():
            raise HTTPException(400, "Email already exists")

        hashed_pw = bcrypt.hashpw(
            data.password.encode(),
            bcrypt.gensalt()
        ).decode()

        cursor.execute(
            "INSERT INTO users (email, password_hash) VALUES (%s, %s)",
            (data.email, hashed_pw)
        )
        conn.commit()

        return {"message": "User registered"}

    finally:
        cursor.close()
        conn.close()

# =========================
# 로그인
# =========================

@app.post("/auth/login")
def login(data: LoginModel):
    conn = get_db()
    cursor = conn.cursor(dictionary=True)

    try:
        cursor.execute("SELECT * FROM users WHERE email=%s", (data.email,))
        user = cursor.fetchone()

        if not user:
            raise HTTPException(401, "Invalid credentials")

        if not bcrypt.checkpw(
            data.password.encode(),
            user["password_hash"].encode()
        ):
            raise HTTPException(401, "Invalid credentials")

        # 기존 refresh 전부 revoke (보안 강화)
        cursor.execute(
            "UPDATE refresh_tokens SET revoked=TRUE WHERE user_id=%s",
            (user["id"],)
        )

        access_token = create_access_token(user["id"])
        refresh_token, expire = create_refresh_token(user["id"])

        cursor.execute(
            """
            INSERT INTO refresh_tokens (user_id, token, expires_at)
            VALUES (%s, %s, %s)
            """,
            (user["id"], refresh_token, expire)
        )
        conn.commit()

        return {
            "access_token": access_token,
            "refresh_token": refresh_token,
            "token_type": "bearer"
        }

    finally:
        cursor.close()
        conn.close()

# =========================
# Refresh Rotation
# =========================

@app.post("/auth/refresh")
def refresh(data: RefreshModel):
    conn = get_db()
    cursor = conn.cursor(dictionary=True)

    try:
        try:
            payload = jwt.decode(
                data.refresh_token,
                REFRESH_SECRET_KEY,
                algorithms=[ALGORITHM]
            )
            user_id = payload.get("sub")
        except:
            raise HTTPException(401, "Invalid refresh token")

        cursor.execute(
            """
            SELECT * FROM refresh_tokens
            WHERE token=%s AND revoked=FALSE AND expires_at > NOW()
            """,
            (data.refresh_token,)
        )
        token_row = cursor.fetchone()

        if not token_row:
            cursor.execute(
                "UPDATE refresh_tokens SET revoked=TRUE WHERE user_id=%s",
                (user_id,)
            )
            conn.commit()
            raise HTTPException(401, "Token reuse detected")

        # 기존 revoke
        cursor.execute(
            "UPDATE refresh_tokens SET revoked=TRUE WHERE token=%s",
            (data.refresh_token,)
        )

        # 새 발급
        new_refresh, expire = create_refresh_token(int(user_id))
        new_access = create_access_token(int(user_id))

        cursor.execute(
            """
            INSERT INTO refresh_tokens (user_id, token, expires_at)
            VALUES (%s, %s, %s)
            """,
            (user_id, new_refresh, expire)
        )
        conn.commit()

        return {
            "access_token": new_access,
            "refresh_token": new_refresh,
            "token_type": "bearer"
        }

    finally:
        cursor.close()
        conn.close()

# =========================
# 로그아웃
# =========================

@app.post("/auth/logout")
def logout(data: RefreshModel):
    conn = get_db()
    cursor = conn.cursor()

    try:
        cursor.execute(
            "UPDATE refresh_tokens SET revoked=TRUE WHERE token=%s",
            (data.refresh_token,)
        )
        conn.commit()
        return {"message": "Logged out"}

    finally:
        cursor.close()
        conn.close()

# =========================
# Google OAuth 로그인
# =========================

@app.post("/auth/google")
def google_login(data: GoogleLoginModel):
    # Google ID Token 검증
    response = requests.get(
        f"https://oauth2.googleapis.com/tokeninfo?id_token={data.id_token}"
    )

    if response.status_code != 200:
        raise HTTPException(401, "Invalid Google token")

    user_info = response.json()

    if user_info["aud"] != GOOGLE_CLIENT_ID:
        raise HTTPException(401, "Invalid client ID")

    email = user_info["email"]
    provider_id = user_info["sub"]

    conn = get_db()
    cursor = conn.cursor(dictionary=True)

    try:
        # 기존 oauth 계정 확인
        cursor.execute(
            """
            SELECT u.* FROM users u
            JOIN oauth_accounts oa ON u.id = oa.user_id
            WHERE oa.provider='google' AND oa.provider_account_id=%s
            """,
            (provider_id,)
        )
        user = cursor.fetchone()

        if not user:
            # 이메일로 기존 계정 찾기
            cursor.execute("SELECT * FROM users WHERE email=%s", (email,))
            user = cursor.fetchone()

            if not user:
                cursor.execute(
                    "INSERT INTO users (email, is_guest) VALUES (%s, FALSE)",
                    (email,)
                )
                conn.commit()
                user_id = cursor.lastrowid
            else:
                user_id = user["id"]

            cursor.execute(
                """
                INSERT INTO oauth_accounts
                (user_id, provider, provider_account_id, email)
                VALUES (%s, 'google', %s, %s)
                """,
                (user_id, provider_id, email)
            )
            conn.commit()
        else:
            user_id = user["id"]

        access = create_access_token(user_id)
        refresh, expire = create_refresh_token(user_id)

        cursor.execute(
            """
            INSERT INTO refresh_tokens (user_id, token, expires_at)
            VALUES (%s, %s, %s)
            """,
            (user_id, refresh, expire)
        )
        conn.commit()

        return {
            "access_token": access,
            "refresh_token": refresh,
            "token_type": "bearer"
        }

    finally:
        cursor.close()
        conn.close()

# =========================
# 보호 API
# =========================

def get_current_user(credentials: HTTPAuthorizationCredentials = Depends(security)):
    token = credentials.credentials

    try:
        payload = jwt.decode(
            token,
            ACCESS_SECRET_KEY,
            algorithms=[ALGORITHM]
        )
        user_id = payload.get("sub")
    except:
        raise HTTPException(401, "Invalid access token")

    return user_id

@app.get("/users/me")
def get_me(user_id=Depends(get_current_user)):
    return {"user_id": user_id}
