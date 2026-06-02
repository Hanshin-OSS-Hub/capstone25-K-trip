from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from join_api import app as join_app
from UserService_api import app as user_app
from location_api import app as location_app
from board_api import app as board_app
from review_api import app as review_app
from AP_algorithm import router as ai_router

# ── 메인 앱 ──────────────────────────────────────────────────────
app = FastAPI(title="KTrip API", version="1.0.0")

# CORS (Flutter 앱 + 로컬 개발 환경 허용)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],   # 배포 시 실제 도메인으로 교체
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ── 헬스체크 ─────────────────────────────────────────────────────
@app.get("/")
def root():
    return {"status": "KTrip API running"}

# ── AI 일정 라우터 (router 방식이라 직접 include) ─────────────────
app.include_router(ai_router)

# ── 나머지 API 마운트 (각자 app = FastAPI() 방식) ─────────────────
app.mount("/auth",      join_app)       # /auth/login, /auth/register ...
app.mount("/users",     user_app)       # /users/me, /users/settings ...
app.mount("/location",  location_app)   # /location/locations, /location/location-categories ...
app.mount("/board",     board_app)      # /board/...
app.mount("/review",    review_app)     # /review/...

# ── 실행 ─────────────────────────────────────────────────────────
if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)