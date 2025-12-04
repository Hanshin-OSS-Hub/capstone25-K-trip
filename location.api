from fastapi import FastAPI, HTTPException, Query
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import Optional, List
from datetime import datetime, time
import mysql.connector
from mysql.connector import pooling, Error
import os
import logging
from enum import Enum

# ================== 로깅 설정 ==================
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s"
)
logger = logging.getLogger("location-api")

# ================== FastAPI 앱 ==================
app = FastAPI(title="Location API", version="1.1.0")

# CORS 설정
app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "http://localhost:3000",
        "http://localhost:5173",
        "http://localhost:8080",
    ],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ================== DB 설정 ==================
DB_CONFIG = {
    "host": os.getenv("DB_HOST", "localhost"),
    "user": os.getenv("DB_USER", "root"),
    "password": os.getenv("DB_PASSWORD", ""),
    "database": os.getenv("DB_NAME", "ktrip"),
    "charset": "utf8mb4",
}

try:
    db_pool = pooling.MySQLConnectionPool(
        pool_name="location_pool",
        pool_size=10,
        pool_reset_session=True,
        **DB_CONFIG,
    )
    logger.info("Location DB pool created")
except Error as e:
    logger.error(f"Pool creation failed: {str(e)}")
    db_pool = None


def get_db_connection():
    try:
        return db_pool.get_connection() if db_pool else mysql.connector.connect(**DB_CONFIG)
    except Error as e:
        logger.error(f"DB connection failed: {str(e)}")
        raise HTTPException(status_code=500, detail="Database connection failed")


# ================== ENUM / 모델 ==================
class Language(str, Enum):
    ko = "ko"
    en = "en"
    ja = "ja"
    zh = "zh"


class SortBy(str, Enum):
    latest = "latest"
    name = "name"
    popular = "popular"


class LocationCategory(BaseModel):
    category_id: int
    category_name: str


class LocationTag(BaseModel):
    tag_id: int
    tag_name: str


class LocationHour(BaseModel):
    day_of_week: str
    open_time: Optional[time]
    close_time: Optional[time]
    is_open: bool


class LocationImage(BaseModel):
    image_id: int
    image_url: str
    is_primary: bool
    source: str
    uploaded_at: datetime


class LocationApiSource(BaseModel):
    source_id: int
    source_name: str
    external_place_id: Optional[str]
    rating: Optional[float]
    review_count: Optional[int]
    synced_at: datetime


class LocationSummary(BaseModel):
    location_id: int
    name: str
    address: Optional[str]
    country_code: str
    city: Optional[str]
    latitude: float
    longitude: float
    category_id: int
    category_name: str
    primary_image: Optional[str]


class LocationDetail(BaseModel):
    location_id: int
    name_ko: str
    name_en: Optional[str]
    name_ja: Optional[str]
    name_zh: Optional[str]

    address_ko: Optional[str]
    address_en: Optional[str]

    country_code: str
    city: Optional[str]
    latitude: float
    longitude: float

    category_id: int
    category_name_ko: str
    category_name_en: str
    category_name_ja: Optional[str]
    category_name_zh: Optional[str]

    tags: List[LocationTag]
    hours: List[LocationHour]
    images: List[LocationImage]
    api_sources: List[LocationApiSource]


# ================== 시작 시 확인 ==================
@app.on_event("startup")
async def startup_event():
    logger.info("🚀 Location API Starting...")
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("SHOW TABLES LIKE 'locations'")
        if not cursor.fetchone():
            logger.warning("⚠️ 'locations' table missing")
        cursor.close()
        conn.close()
    except Exception as e:
        logger.error(str(e))


# ================== 건강 체크 ==================
@app.get("/location-api/health")
def health_check():
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("SELECT 1")
        cursor.close()
        conn.close()
        return {"status": "healthy"}
    except Exception as e:
        return {"status": "unhealthy", "error": str(e)}


# ================== 카테고리 ==================
@app.get("/location-categories", response_model=List[LocationCategory])
def get_location_categories(language: Language = Language.ko):
    conn = get_db_connection()
    cursor = conn.cursor(dictionary=True)
    try:
        lang_column = f"category_name_{language.value}"
        query = f"""
            SELECT category_id, {lang_column} AS category_name
            FROM location_categories
            ORDER BY category_id
        """
        cursor.execute(query)
        rows = cursor.fetchall()
        return [LocationCategory(**row) for row in rows]
    finally:
        cursor.close()
        conn.close()


# ================== 태그 ==================
@app.get("/location-tags", response_model=List[LocationTag])
def get_location_tags():
    conn = get_db_connection()
    cursor = conn.cursor(dictionary=True)
    try:
        cursor.execute("SELECT tag_id, tag_name FROM location_tags ORDER BY tag_name")
        rows = cursor.fetchall()
        return [LocationTag(**row) for row in rows]
    finally:
        cursor.close()
        conn.close()


# ================== 관광지 목록 조회 ==================
@app.get("/locations")
def get_locations(
    page: int = Query(1, ge=1),
    limit: int = Query(20, ge=1, le=100),
    category_id: Optional[int] = None,
    tag: Optional[str] = None,
    city: Optional[str] = None,
    keyword: Optional[str] = None,
    language: Language = Language.ko,
    sort_by: SortBy = SortBy.latest,
):
    conn = get_db_connection()
    cursor = conn.cursor(dictionary=True)

    try:
        offset = (page - 1) * limit

        # ---------- 언어별 name fallback ----------
        name_col = f"""
            COALESCE(
                l.name_{language.value},
                l.name_en,
                l.name_ko
            )
        """

        # ---------- address fallback ----------
        addr_col = """
            CASE 
                WHEN %s = 'ko' THEN l.address_ko
                ELSE l.address_en
            END
        """

        where_sql = ["1=1"]
        params_list = [language.value]  # address CASE WHEN

        if category_id:
            where_sql.append("l.location_category_id = %s")
            params_list.append(category_id)

        if city:
            where_sql.append("l.city = %s")
            params_list.append(city)

        if keyword:
            where_sql.append(f"({name_col} LIKE %s OR l.address_ko LIKE %s OR l.address_en LIKE %s)")
            like = f"%{keyword}%"
            params_list.extend([like, like, like])

        if tag:
            where_sql.append("""
                EXISTS (
                    SELECT 1
                    FROM location_tag_map m
                    JOIN location_tags t ON m.tag_id = t.tag_id
                    WHERE m.location_id = l.location_id
                      AND t.tag_name = %s
                )
            """)
            params_list.append(tag)

        where_clause = " AND ".join(where_sql)

        order_clause = {
            SortBy.latest: "l.created_at DESC",
            SortBy.name: f"{name_col} COLLATE utf8mb4_unicode_ci ASC",
            SortBy.popular: "l.created_at DESC",  # 확장 가능
        }[sort_by]

        query = f"""
            SELECT
                l.location_id,
                {name_col} AS name,
                {addr_col} AS address,
                l.country_code,
                l.city,
                l.latitude,
                l.longitude,
                l.location_category_id AS category_id,
                c.category_name_{language.value} AS category_name,
                (
                    SELECT image_url FROM location_images
                    WHERE location_id = l.location_id
                    ORDER BY is_primary DESC, uploaded_at DESC
                    LIMIT 1
                ) AS primary_image
            FROM locations l
            JOIN location_categories c ON l.location_category_id = c.category_id
            WHERE {where_clause}
            ORDER BY {order_clause}
            LIMIT %s OFFSET %s
        """

        params_list.extend([limit, offset])
        cursor.execute(query, params_list)
        rows = cursor.fetchall()
        summaries = [LocationSummary(**row) for row in rows]

        # ---------- Count Query ----------
        count_params = params_list[:-2]  # limit, offset 제거
        count_query = f"""
            SELECT COUNT(*) AS total
            FROM locations l
            JOIN location_categories c ON l.location_category_id = c.category_id
            WHERE {where_clause}
        """

        cursor.execute(count_query, count_params)
        total = cursor.fetchone()["total"]
        total_pages = (total + limit - 1) // limit

        return {
            "locations": [x.dict() for x in summaries],
            "pagination": {
                "page": page,
                "limit": limit,
                "total": total,
                "total_pages": total_pages,
                "has_next": page < total_pages,
                "has_prev": page > 1,
            },
        }

    finally:
        cursor.close()
        conn.close()


# ================== 관광지 상세 ==================
@app.get("/locations/{location_id}", response_model=LocationDetail)
def get_location_detail(location_id: int):
    conn = get_db_connection()
    cursor = conn.cursor(dictionary=True)

    try:
        # ---------- Base ----------
        cursor.execute("""
            SELECT
                l.location_id, l.name_ko, l.name_en, l.name_ja, l.name_zh,
                l.address_ko, l.address_en,
                l.country_code, l.city,
                l.latitude, l.longitude,
                c.category_id,
                c.category_name_ko, c.category_name_en,
                c.category_name_ja, c.category_name_zh
            FROM locations l
            JOIN location_categories c ON l.location_category_id = c.category_id
            WHERE l.location_id = %s
        """, (location_id,))
        base = cursor.fetchone()

        if not base:
            raise HTTPException(status_code=404, detail="Location not found")

        # ---------- 태그 ----------
        cursor.execute("""
            SELECT t.tag_id, t.tag_name
            FROM location_tag_map m
            JOIN location_tags t ON m.tag_id = t.tag_id
            WHERE m.location_id = %s
        """, (location_id,))
        tags = [LocationTag(**row) for row in cursor.fetchall()]

        # ---------- 운영시간 ----------
        cursor.execute("""
            SELECT day_of_week, open_time, close_time, is_open
            FROM location_hours
            WHERE location_id = %s
            ORDER BY FIELD(day_of_week,'Mon','Tue','Wed','Thu','Fri','Sat','Sun')
        """, (location_id,))
        hours = [LocationHour(**row) for row in cursor.fetchall()]

        # ---------- 이미지 ----------
        cursor.execute("""
            SELECT image_id, image_url, is_primary, source, uploaded_at
            FROM location_images
            WHERE location_id = %s
            ORDER BY is_primary DESC, uploaded_at DESC
        """, (location_id,))
        imgs = [LocationImage(**row) for row in cursor.fetchall()]

        # ---------- API 소스 ----------
        cursor.execute("""
            SELECT source_id, source_name, external_place_id,
                   rating, review_count, synced_at
            FROM location_api_sources
            WHERE location_id = %s
        """, (location_id,))
        apis = [LocationApiSource(**row) for row in cursor.fetchall()]

        return LocationDetail(
            **base,
            tags=tags,
            hours=hours,
            images=imgs,
            api_sources=apis
        )

    finally:
        cursor.close()
        conn.close()


# ================== UVICORN ==================
if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8002)
