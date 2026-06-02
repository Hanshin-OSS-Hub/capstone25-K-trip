from fastapi import FastAPI, Depends, HTTPException
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from pydantic import BaseModel
from typing import Optional
import mysql.connector
import bcrypt
import jwt
import os

# ── 앱 / 보안 설정 ────────────────────────────────────────────────
app = FastAPI()
security = HTTPBearer()

ACCESS_SECRET_KEY = os.getenv("ACCESS_SECRET_KEY")
ALGORITHM = "HS256"

DB_CONFIG = {
    "host":     os.getenv("DB_HOST"),
    "user":     os.getenv("DB_USER"),
    "password": os.getenv("DB_PASSWORD"),
    "database": os.getenv("DB_NAME"),
}

# ── DB 연결 ──────────────────────────────────────────────────────
def get_db():
    return mysql.connector.connect(**DB_CONFIG)

# ── 토큰 인증 의존성 ──────────────────────────────────────────────
def get_current_user(credentials: HTTPAuthorizationCredentials = Depends(security)):
    token = credentials.credentials
    try:
        payload = jwt.decode(token, ACCESS_SECRET_KEY, algorithms=[ALGORITHM])
        user_id = payload.get("sub")
    except Exception:
        raise HTTPException(401, "Invalid access token")
    return user_id


# ── 현재 사용자 정보 조회 ─────────────────────────────────────────
@app.get("/me")                          # main.py에서 /users 로 마운트됨 → /users/me
def get_me(user_id=Depends(get_current_user)):
    conn = get_db()
    cursor = conn.cursor(dictionary=True)
    try:
        cursor.execute("""
            SELECT u.id, u.email, u.nickname,
                   up.bio, up.birth_date, up.gender,
                   up.country_code, up.city
            FROM users u
            LEFT JOIN user_profiles up ON u.id = up.user_id
            WHERE u.id = %s
        """, (user_id,))
        user = cursor.fetchone()
        if not user:
            raise HTTPException(404, "User not found")
        return user
    finally:
        cursor.close()
        conn.close()


# ── 프로필 수정 ──────────────────────────────────────────────────
class UpdateProfileModel(BaseModel):
    nickname: Optional[str] = None
    bio: Optional[str] = None
    birth_date: Optional[str] = None
    gender: Optional[str] = None
    country_code: Optional[str] = None
    city: Optional[str] = None


@app.put("/me")                          # → /users/me
def update_profile(data: UpdateProfileModel, user_id=Depends(get_current_user)):
    conn = get_db()
    cursor = conn.cursor()
    try:
        if data.nickname:
            cursor.execute(
                "UPDATE users SET nickname=%s WHERE id=%s",
                (data.nickname, user_id)
            )
        cursor.execute("""
            INSERT INTO user_profiles
                (user_id, bio, birth_date, gender, country_code, city)
            VALUES (%s, %s, %s, %s, %s, %s)
            ON DUPLICATE KEY UPDATE
                bio=VALUES(bio), birth_date=VALUES(birth_date),
                gender=VALUES(gender), country_code=VALUES(country_code),
                city=VALUES(city)
        """, (user_id, data.bio, data.birth_date, data.gender, data.country_code, data.city))
        conn.commit()
        return {"message": "Profile updated"}
    finally:
        cursor.close()
        conn.close()


# ── 비밀번호 변경 ─────────────────────────────────────────────────
class ChangePasswordModel(BaseModel):
    current_password: str
    new_password: str


@app.post("/change-password")            # → /users/change-password
def change_password(data: ChangePasswordModel, user_id=Depends(get_current_user)):
    conn = get_db()
    cursor = conn.cursor(dictionary=True)
    try:
        cursor.execute("SELECT password_hash FROM users WHERE id=%s", (user_id,))
        user = cursor.fetchone()
        if not user:
            raise HTTPException(404, "User not found")
        if not bcrypt.checkpw(data.current_password.encode(), user["password_hash"].encode()):
            raise HTTPException(400, "Current password incorrect")
        new_hash = bcrypt.hashpw(data.new_password.encode(), bcrypt.gensalt()).decode()
        cursor.execute("UPDATE users SET password_hash=%s WHERE id=%s", (new_hash, user_id))
        conn.commit()
        return {"message": "Password updated"}
    finally:
        cursor.close()
        conn.close()


# ── 설정 조회 ────────────────────────────────────────────────────
@app.get("/settings")                    # → /users/settings
def get_settings(user_id=Depends(get_current_user)):
    conn = get_db()
    cursor = conn.cursor(dictionary=True)
    try:
        cursor.execute(
            "SELECT language, theme, push_enabled FROM user_settings WHERE user_id=%s",
            (user_id,)
        )
        settings = cursor.fetchone()
        return settings or {"language": "en", "theme": "light", "push_enabled": True}
    finally:
        cursor.close()
        conn.close()


# ── 설정 변경 ────────────────────────────────────────────────────
class UpdateSettingsModel(BaseModel):
    language: str
    theme: str
    push_enabled: bool


@app.put("/settings")                    # → /users/settings
def update_settings(data: UpdateSettingsModel, user_id=Depends(get_current_user)):
    conn = get_db()
    cursor = conn.cursor()
    try:
        cursor.execute("""
            INSERT INTO user_settings (user_id, language, theme, push_enabled)
            VALUES (%s, %s, %s, %s)
            ON DUPLICATE KEY UPDATE
                language=VALUES(language), theme=VALUES(theme),
                push_enabled=VALUES(push_enabled)
        """, (user_id, data.language, data.theme, data.push_enabled))
        conn.commit()
        return {"message": "Settings updated"}
    finally:
        cursor.close()
        conn.close()


# ── 회원 탈퇴 ────────────────────────────────────────────────────
@app.delete("/me")                       # → /users/me
def delete_account(user_id=Depends(get_current_user)):
    conn = get_db()
    cursor = conn.cursor()
    try:
        cursor.execute("DELETE FROM users WHERE id=%s", (user_id,))
        conn.commit()
        return {"message": "Account deleted"}
    finally:
        cursor.close()
        conn.close()