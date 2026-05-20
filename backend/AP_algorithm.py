from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from typing import List, Optional
import aiomysql
import os
import math
from datetime import date, timedelta

router = APIRouter()

class PlanRequest(BaseModel):
    region: str
    start_date: str
    end_date: str
    companion: str
    themes: List[str]

DB_CONFIG = {
    "host":     os.environ.get("DB_HOST", "localhost"),
    "port":     int(os.environ.get("DB_PORT", 3306)),
    "user":     os.environ.get("DB_USER", "root"),
    "password": os.environ.get("DB_PASSWORD", ""),
    "db":       os.environ.get("DB_NAME", "ktrip"),
    "charset":  "utf8mb4",
}

FOOD_CATEGORIES = {"음식점", "카페"}
FOOD_THEMES     = {"맛집", "디저트"}

def haversine(p1: dict, p2: dict) -> float:
    R = 6371
    lat1, lon1 = math.radians(float(p1["lat"])), math.radians(float(p1["lon"]))
    lat2, lon2 = math.radians(float(p2["lat"])), math.radians(float(p2["lon"]))
    dlat, dlon = lat2 - lat1, lon2 - lon1
    a = math.sin(dlat/2)**2 + math.cos(lat1)*math.cos(lat2)*math.sin(dlon/2)**2
    return R * 2 * math.asin(math.sqrt(a))

async def fetch_by_theme(region: str, theme: str, limit: int) -> dict:
    query = """
        SELECT
            p.place_id, p.name_ko, p.category,
            p.address, p.description, p.lat, p.lon,
            %s AS primary_theme
        FROM places p
        JOIN place_theme pt ON p.place_id = pt.place_id
        JOIN themes t       ON pt.theme_id = t.theme_id
        WHERE p.region = %s
          AND p.category != '숙박'
          AND t.theme_name = %s
        GROUP BY p.place_id, p.name_ko, p.category,
                 p.address, p.description, p.lat, p.lon
        ORDER BY RAND()
        LIMIT %s
    """
    async with aiomysql.connect(**DB_CONFIG) as conn:
        async with conn.cursor(aiomysql.DictCursor) as cur:
            await cur.execute(query, [theme, region, theme, limit])
            rows = await cur.fetchall()
    food  = [dict(r) for r in rows if r["category"] in FOOD_CATEGORIES]
    other = [dict(r) for r in rows if r["category"] not in FOOD_CATEGORIES]
    return {"food": food, "other": other}

async def fetch_attractions(region: str, limit: int, exclude_ids: set) -> List[dict]:
    query = """
        SELECT place_id, name_ko, category,
               address, description, lat, lon,
               '관광지' AS primary_theme
        FROM places
        WHERE region = %s AND category = '관광지'
        ORDER BY RAND()
        LIMIT %s
    """
    async with aiomysql.connect(**DB_CONFIG) as conn:
        async with conn.cursor(aiomysql.DictCursor) as cur:
            await cur.execute(query, [region, limit * 2])
            rows = await cur.fetchall()
    return [dict(r) for r in rows if r["place_id"] not in exclude_ids][:limit]

async def fetch_accommodations(region: str) -> List[dict]:
    query = """
        SELECT place_id, name_ko, address, lat, lon, description
        FROM places WHERE region = %s AND category = '숙박'
    """
    async with aiomysql.connect(**DB_CONFIG) as conn:
        async with conn.cursor(aiomysql.DictCursor) as cur:
            await cur.execute(query, [region])
            rows = await cur.fetchall()
    return [dict(r) for r in rows]

def optimize_order(places: List[dict]) -> List[dict]:
    valid = [p for p in places if p.get("lat") and p.get("lon")]
    if not valid:
        return places
    unvisited = valid.copy()
    ordered   = [unvisited.pop(0)]
    while unvisited:
        current = ordered[-1]
        nearest = min(unvisited, key=lambda p: haversine(current, p))
        ordered.append(nearest)
        unvisited.remove(nearest)
    return ordered

def arrange_day(food: List[dict], other: List[dict]) -> List[dict]:
    """other → food 교대 배치 (음식이 연속으로 안 붙게)"""
    arranged = []
    f = list(food)
    o = list(other)
    while f or o:
        if o:
            arranged.append(o.pop(0))
        if f:
            arranged.append(f.pop(0))
    return arranged

WIDE_AREA_REGIONS = {"전남", "전북", "경남", "경북", "강원", "충남", "충북", "경기"}

def is_multi_region(region: str) -> bool:
    return region in WIDE_AREA_REGIONS

def nearest_hotel(anchor: dict, accommodations: List[dict]) -> Optional[dict]:
    valid_acc = [a for a in accommodations if a.get("lat") and a.get("lon")]
    if not valid_acc:
        return None
    best = min(valid_acc, key=lambda a: haversine(anchor, a))
    return {
        "place_id":    best["place_id"],
        "name_ko":     best["name_ko"],
        "category":    "숙박",
        "address":     best["address"],
        "description": best.get("description", ""),
        "lat":         best["lat"],
        "lon":         best["lon"],
        "themes":      "숙박",
    }

@router.post("/api/travel/plan")
async def generate_travel_plan(req: PlanRequest):
    if req.start_date >= req.end_date:
        raise HTTPException(status_code=400, detail="end_date는 start_date 이후여야 합니다.")
    if not req.themes:
        raise HTTPException(status_code=400, detail="테마를 최소 1개 이상 선택해주세요.")

    nights    = (date.fromisoformat(req.end_date) - date.fromisoformat(req.start_date)).days
    days      = nights + 1
    multi     = is_multi_region(req.region)
    base_date = date.fromisoformat(req.start_date)

    has_food_theme = any(t in FOOD_THEMES for t in req.themes)
    only_food      = has_food_theme and all(t in FOOD_THEMES for t in req.themes)
    other_themes   = [t for t in req.themes if t not in FOOD_THEMES]

    try:
        # 테마별로 따로 버킷 관리 (균등 배분을 위해)
        food_bucket         = []  # 음식 슬롯용
        theme_buckets       = {}  # 일반 테마별 버킷 {theme: [places]}
        seen_ids            = set()

        for theme in req.themes:
            result = await fetch_by_theme(req.region, theme, 40)

            # 음식 슬롯
            for p in result["food"]:
                if p["place_id"] not in seen_ids:
                    food_bucket.append(p)
                    seen_ids.add(p["place_id"])

            # 일반 슬롯 — 테마별로 따로 저장
            if theme not in FOOD_THEMES:
                theme_buckets[theme] = []
                for p in result["other"]:
                    if p["place_id"] not in seen_ids:
                        theme_buckets[theme].append(p)
                        seen_ids.add(p["place_id"])

        # 음식이 있는지 여부 결정
        has_food = has_food_theme or len(food_bucket) > 0

        # 슬롯 계산
        if has_food:
            FOOD_SLOT  = 3 if only_food else 2
            OTHER_SLOT = 5 - FOOD_SLOT
        else:
            FOOD_SLOT  = 0
            OTHER_SLOT = 3

        # 관광지 자동 채우기 (맛집만 선택 or other 부족할 때)
        if only_food or not other_themes:
            attractions = await fetch_attractions(req.region, OTHER_SLOT * days + 5, seen_ids)
            theme_buckets["관광지(자동)"] = attractions

        accommodations = await fetch_accommodations(req.region)

    except Exception as e:
        raise HTTPException(status_code=500, detail=f"DB 조회 실패: {str(e)}")

    # 단일 지역 숙소 미리 결정
    single_hotel = None
    if not multi and accommodations:
        first = next(iter(theme_buckets.values()), [])
        anchor = first[0] if first else (food_bucket[0] if food_bucket else None)
        if anchor:
            single_hotel = nearest_hotel(anchor, accommodations)

    schedule = []
    for i in range(days):
        # 음식 슬롯
        day_food = food_bucket[i * FOOD_SLOT : (i+1) * FOOD_SLOT] if FOOD_SLOT > 0 else []

        # 일반 슬롯 — 테마별로 균등하게 1개씩 순환 배분
        day_other = []
        theme_keys = list(theme_buckets.keys())
        n_themes   = len(theme_keys)

        if n_themes > 0:
            per_theme = OTHER_SLOT // n_themes
            extra     = OTHER_SLOT % n_themes

            for j, theme in enumerate(theme_keys):
                count  = per_theme + (1 if j < extra else 0)
                picked = theme_buckets[theme][i * count : (i+1) * count]

                # 부족하면 다음 인덱스에서 가져오기
                if len(picked) < count:
                    picked = theme_buckets[theme][:count]

                day_other.extend(picked)

        # 동선 최적화
        opt_food  = optimize_order(day_food)
        opt_other = optimize_order(day_other)

        # 교대 배치
        arranged = arrange_day(opt_food, opt_other)

        places_list = [
            {
                "place_id":    p["place_id"],
                "name_ko":     p["name_ko"],
                "category":    p["category"],
                "address":     p["address"],
                "description": p.get("description", ""),
                "lat":         p["lat"],
                "lon":         p["lon"],
                "themes":      p.get("primary_theme", ""),
            }
            for p in arranged
        ]

        # 마지막 날 숙소 없음
        is_last_day = (i == days - 1)
        if not is_last_day and accommodations:
            hotel = nearest_hotel(arranged[-1], accommodations) if (multi and arranged) else single_hotel
            if hotel:
                places_list.append(hotel)

        schedule.append({
            "day":    i + 1,
            "date":   str(base_date + timedelta(days=i)),
            "places": places_list,
        })

    return {
        "region":          req.region,
        "companion":       req.companion,
        "nights":          nights,
        "days":            days,
        "is_multi_region": multi,
        "schedule":        schedule,
    }