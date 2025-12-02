import datetime
from typing import List, Optional
from dataclasses import dataclass, field
import math


# ==================== 데이터 클래스 정의 ====================

@dataclass
class RoutePreference:
    """사용자의 여행 선호도 (route_preferences 테이블)"""
    preference_id: Optional[int] = None
    user_id: int = 0
    start_date: Optional[datetime.date] = None
    end_date: Optional[datetime.date] = None
    theme_id: int = 0
    schedule_type: str = "relaxed"  # relaxed or packed
    travelers_count: int = 1
    preferred_language: str = "en"
    transport_mode: str = "public"  # walk, public, taxi, car
    created_at: Optional[datetime.datetime] = None


@dataclass
class Activity:
    """일정에 포함될 활동/관광지 (itinerary_activities 테이블)"""
    # 기본 정보
    activity_id: Optional[int] = None
    activity_name: str = ""
    lat: float = 0.0
    lon: float = 0.0
    
    # 일정 관련
    itinerary_id: Optional[int] = None
    activity_order: int = 0
    activity_time: Optional[datetime.time] = None
    activity_description: Optional[str] = None
    
    # 위치 정보
    location_id: Optional[int] = None  # locations 테이블 FK
    location_name: Optional[str] = None
    location_address: Optional[str] = None
    
    # 비용 및 시간
    estimated_duration_minutes: int = 120  # 기본 2시간
    estimated_cost: Optional[float] = None
    
    # 카테고리
    activity_category_id: Optional[int] = None
    
    # 알고리즘용 추가 필드
    priority_score: float = 0.0
    categories: List[str] = field(default_factory=list)  # 알고리즘 계산용
    
    @property
    def avg_duration_hours(self) -> float:
        """시간 단위로 변환"""
        return self.estimated_duration_minutes / 60


@dataclass
class DailyItinerary:
    """일일 일정 (route_itinerary 테이블)"""
    itinerary_id: Optional[int] = None
    route_id: Optional[int] = None
    day_number: int = 1
    day_date: datetime.date = None
    day_description: Optional[str] = None
    
    # 활동 리스트
    activities: List[Activity] = field(default_factory=list)
    
    # 계산 값
    total_distance: float = 0.0
    total_estimated_cost: float = 0.0


@dataclass
class Route:
    """전체 여행 루트 (recommended_routes 테이블)"""
    route_id: Optional[int] = None
    preference_id: Optional[int] = None
    route_name: str = ""
    route_description: Optional[str] = None
    total_estimated_cost: Optional[float] = None
    difficulty_level: str = "easy"  # easy, moderate, challenging
    generated_at: Optional[datetime.datetime] = None
    is_active: bool = True
    ai_model: str = "custom_greedy_algorithm"
    ai_version: str = "1.0"
    
    # 일정 리스트
    itinerary: List[DailyItinerary] = field(default_factory=list)


# ==================== DatabaseConnector 클래스 ====================

class DatabaseConnector:
    """데이터베이스 연결 및 데이터 조회"""
    
    def __init__(self, db_connection):
        """
        Parameters:
        - db_connection: pymysql.connect() 객체
        """
        self.conn = db_connection
    
    def fetch_activities_by_theme(self, theme_id: int, transport_mode: str = "public"):
        """
        테마에 맞는 활동/관광지 조회 - API 호출 방식
        
        Parameters:
        - theme_id: trip_themes 테이블의 theme_id
        - transport_mode: 이동수단
        
        Returns:
        - List[Activity]: 조건에 맞는 활동 리스트
        """
        # API를 통해 관광지 데이터 가져오기
        return self._fetch_activities_from_api(theme_id, transport_mode)
    
    def _fetch_activities_from_api(self, theme_id: int, transport_mode: str = "public"):
        """
        API를 통해 관광지 데이터 가져오기
        
        실제 API 엔드포인트에 맞게 수정
        
        Parameters:
        - theme_id: 테마 ID
        - transport_mode: 이동수단
        
        Returns:
        - List[Activity]: 활동 리스트
        """
        import requests
        
        activities = []
        
        try:
            # 팀 자체 백엔드 API 호출
            
            # API 엔드포인트 설정 (팀 API 주소로 수정)
            api_url = "http://your-backend-api.com/api/locations"
            
            # 요청 파라미터
            params = {
                'theme_id': theme_id,
                'transport_mode': transport_mode,
                'limit': 100
            }
            
            # 헤더 (인증 토큰이 필요한 경우)
            headers = {
                'Authorization': 'Bearer YOUR_API_TOKEN',  # 필요시
                'Content-Type': 'application/json'
            }
            
            # API 호출
            response = requests.get(api_url, params=params, headers=headers, timeout=10)
            response.raise_for_status()  # HTTP 에러 체크
            
            data = response.json()
            
            # 응답 데이터 파싱 (API 응답 구조에 맞게 수정)
            
            if data.get('success') and data.get('data'):
                for item in data['data']:
                    activities.append(Activity(
                        location_id=item.get('id'),
                        activity_name=item.get('name', ''),
                        lat=float(item.get('latitude', 0)),
                        lon=float(item.get('longitude', 0)),
                        activity_description=item.get('description'),
                        location_name=item.get('name'),
                        location_address=item.get('address'),
                        estimated_duration_minutes=item.get('duration', 120),
                        estimated_cost=float(item.get('cost', 0)) if item.get('cost') else None,
                        activity_category_id=item.get('category_id'),
                        categories=[item.get('category_name')] if item.get('category_name') else []
                    ))
            
        except requests.exceptions.RequestException as e:
            print(f"API 호출 실패: {e}")
            # API 실패시 폴백: DB에서 캐시된 데이터 조회 또는 빈 리스트 반환
            activities = self._fetch_cached_activities(theme_id)
        
        except Exception as e:
            print(f"데이터 처리 실패: {e}")
            activities = []
        
        return activities

    def save_route(self, route: Route, preference: RoutePreference):
        """
        생성된 루트를 DB에 저장
        
        Parameters:
        - route: Route 객체
        - preference: RoutePreference 객체
        
        Returns:
        - route_id: 저장된 route의 ID
        """
        cursor = self.conn.cursor()
        
        try:
            # 1. route_preferences 저장 (이미 있다면 스킵)
            if preference.preference_id is None:
                cursor.execute("""
                    INSERT INTO route_preferences 
                    (user_id, start_date, end_date, theme_id, schedule_type, 
                     travelers_count, preferred_language, transport_mode)
                    VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
                """, (
                    preference.user_id, preference.start_date, preference.end_date,
                    preference.theme_id, preference.schedule_type,
                    preference.travelers_count, preference.preferred_language,
                    preference.transport_mode
                ))
                preference.preference_id = cursor.lastrowid
            
            # 2. recommended_routes 저장
            cursor.execute("""
                INSERT INTO recommended_routes 
                (preference_id, route_name, route_description, total_estimated_cost,
                 difficulty_level, ai_model, ai_version, is_active)
                VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
            """, (
                preference.preference_id, route.route_name, route.route_description,
                route.total_estimated_cost, route.difficulty_level,
                route.ai_model, route.ai_version, route.is_active
            ))
            route.route_id = cursor.lastrowid
            
            # 3. route_itinerary 저장 (각 날짜별)
            for daily in route.itinerary:
                cursor.execute("""
                    INSERT INTO route_itinerary 
                    (route_id, day_number, day_date, day_description)
                    VALUES (%s, %s, %s, %s)
                """, (
                    route.route_id, daily.day_number, daily.day_date, daily.day_description
                ))
                daily.itinerary_id = cursor.lastrowid
                
                # 4. itinerary_activities 저장 (각 활동별)
                for activity in daily.activities:
                    cursor.execute("""
                        INSERT INTO itinerary_activities 
                        (itinerary_id, activity_order, activity_time, activity_name,
                         activity_description, location_id, location_name, location_address,
                         coordinates, estimated_duration_minutes, estimated_cost, activity_category_id)
                        VALUES (%s, %s, %s, %s, %s, %s, %s, %s, POINT(%s, %s), %s, %s, %s)
                    """, (
                        daily.itinerary_id, activity.activity_order, activity.activity_time,
                        activity.activity_name, activity.activity_description,
                        activity.location_id, activity.location_name, activity.location_address,
                        activity.lon, activity.lat,  # POINT는 (경도, 위도) 순서
                        activity.estimated_duration_minutes, activity.estimated_cost,
                        activity.activity_category_id
                    ))
                    activity.activity_id = cursor.lastrowid
            
            self.conn.commit()
            return route.route_id
            
        except Exception as e:
            self.conn.rollback()
            raise Exception(f"루트 저장 실패: {str(e)}")


# ==================== TravelRecommendationSystem 클래스 ====================

class TravelRecommendationSystem:
    """여행 일정 추천 시스템"""
    
    def __init__(self, db_connector: DatabaseConnector):
        self.db = db_connector
    
    def calculate_distance(self, lat1: float, lon1: float, lat2: float, lon2: float) -> float:
        """두 지점 간 거리 계산 (Haversine formula, km)"""
        R = 6371
        
        dlat = math.radians(lat2 - lat1)
        dlon = math.radians(lon2 - lon1)
        a = (math.sin(dlat / 2) ** 2 + 
             math.cos(math.radians(lat1)) * math.cos(math.radians(lat2)) * 
             math.sin(dlon / 2) ** 2)
        c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))
        
        return R * c
    
    def calculate_match_score(self, activity: Activity, theme_categories: List[str]) -> float:
        """활동과 테마 카테고리 매칭 점수 계산"""
        matched = sum(1 for cat in theme_categories if cat in activity.categories)
        category_diversity = len(set(activity.categories) & set(theme_categories))
        return matched * 2 + category_diversity
    
    def optimize_daily_route(self, 
                            activities: List[Activity], 
                            start_time: int = 9,
                            max_hours: int = 12,
                            target_count: int = 4,
                            schedule_type: str = "relaxed") -> tuple:
        """
        하루 일정 최적화
        
        Parameters:
        - schedule_type: "relaxed" (여유) or "packed" (빡빡)
        """
        if not activities:
            return [], 0.0, 0.0
        
        # schedule_type에 따라 시간 조정
        if schedule_type == "packed":
            max_hours = 14  # 더 많은 시간
            target_count = min(6, target_count + 1)
        else:
            max_hours = 10  # 여유있게
            target_count = min(4, target_count)
        
        selected = []
        available = activities.copy()
        total_distance = 0.0
        total_cost = 0.0
        current_time = start_time
        
        # 첫 활동 선택
        first = max(available, key=lambda a: a.priority_score)
        available.remove(first)
        first.activity_order = 1
        first.activity_time = datetime.time(current_time, 0)
        selected.append(first)
        
        current_lat, current_lon = first.lat, first.lon
        current_time += first.avg_duration_hours
        if first.estimated_cost:
            total_cost += first.estimated_cost
        
        # 다음 활동들 선택
        order = 2
        while available and len(selected) < target_count and current_time < start_time + max_hours:
            valid = [
                a for a in available 
                if current_time + a.avg_duration_hours <= start_time + max_hours
            ]
            
            if not valid:
                break
            
            def selection_score(a):
                dist = self.calculate_distance(current_lat, current_lon, a.lat, a.lon)
                return a.priority_score * 10 - dist
            
            next_activity = max(valid, key=selection_score)
            
            distance = self.calculate_distance(current_lat, current_lon, 
                                              next_activity.lat, next_activity.lon)
            travel_time = distance / 30
            
            if current_time + travel_time + next_activity.avg_duration_hours > start_time + max_hours:
                break
            
            next_activity.activity_order = order
            hour = int(current_time + travel_time)
            minute = int((current_time + travel_time - hour) * 60)
            next_activity.activity_time = datetime.time(hour, minute)
            
            selected.append(next_activity)
            available.remove(next_activity)
            current_lat, current_lon = next_activity.lat, next_activity.lon
            current_time += travel_time + next_activity.avg_duration_hours
            total_distance += distance
            
            if next_activity.estimated_cost:
                total_cost += next_activity.estimated_cost
            
            order += 1
        
        return selected, total_distance, total_cost
    
    def generate_route(self, preference: RoutePreference) -> Route:
        """
        사용자 선호도에 맞는 전체 루트 생성
        
        Parameters:
        - preference: RoutePreference 객체
        
        Returns:
        - Route: 생성된 루트 객체
        """
        
        # 1. 테마에 맞는 활동 가져오기
        all_activities = self.db.fetch_activities_by_theme(
            preference.theme_id, 
            preference.transport_mode
        )
        
        if not all_activities:
            raise Exception("조건에 맞는 활동을 찾을 수 없습니다.")
        
        # 2. 매칭 점수 계산 (테마 카테고리는 별도 조회 필요)
        # 간단히 하기 위해 모든 활동의 카테고리를 사용
        all_categories = list(set(cat for act in all_activities for cat in act.categories))
        
        for activity in all_activities:
            activity.priority_score = self.calculate_match_score(activity, all_categories)
        
        # 3. 점수순 정렬
        all_activities.sort(key=lambda a: a.priority_score, reverse=True)
        
        # 4. 여행 일수 계산
        num_days = (preference.end_date - preference.start_date).days + 1
        
        # 5. 하루 방문 수 계산
        activities_per_day = max(3, min(5, len(all_activities) // num_days))
        
        # 6. 루트 객체 생성
        route = Route(
            preference_id=preference.preference_id,
            route_name=f"{preference.start_date} ~ {preference.end_date} 여행",
            route_description=f"{num_days}일간의 맞춤형 여행 일정",
            difficulty_level="easy" if preference.schedule_type == "relaxed" else "moderate"
        )
        
        # 7. 각 날짜별 일정 생성
        used_activities = set()
        total_route_cost = 0.0
        
        for day in range(num_days):
            current_date = preference.start_date + datetime.timedelta(days=day)
            
            available = [a for a in all_activities if a.location_id not in used_activities]
            
            if not available:
                available = all_activities.copy()
                used_activities.clear()
            
            # 하루 일정 최적화
            daily_activities, distance, cost = self.optimize_daily_route(
                available,
                start_time=9,
                max_hours=12,
                target_count=activities_per_day,
                schedule_type=preference.schedule_type
            )
            
            if daily_activities:
                for act in daily_activities:
                    if act.location_id:
                        used_activities.add(act.location_id)
                
                daily = DailyItinerary(
                    route_id=route.route_id,
                    day_number=day + 1,
                    day_date=current_date,
                    day_description=f"Day {day + 1}: {len(daily_activities)}개 장소 방문",
                    activities=daily_activities,
                    total_distance=round(distance, 2),
                    total_estimated_cost=round(cost, 2)
                )
                
                route.itinerary.append(daily)
                total_route_cost += cost
        
        route.total_estimated_cost = round(total_route_cost, 2)
        
        return route


# ==================== 사용 예시 ====================
"""
# 1. DB 연결
import pymysql

conn = pymysql.connect(
    host='localhost',
    user='root',
    password='your_password',
    db='travel_db',
    charset='utf8mb4',
    cursorclass=pymysql.cursors.DictCursor
)

# 2. 시스템 초기화
db = DatabaseConnector(conn)
system = TravelRecommendationSystem(db)

# 3. 사용자 선호도 설정
preference = RoutePreference(
    user_id=1,
    start_date=datetime.date(2025, 12, 20),
    end_date=datetime.date(2025, 12, 22),
    theme_id=1,  # K-pop 테마
    schedule_type="relaxed",
    travelers_count=2,
    preferred_language="en",
    transport_mode="public"
)

# 4. 루트 생성
route = system.generate_route(preference)

# 5. DB에 저장
route_id = db.save_route(route, preference)

# 6. 결과 확인
print(f"Route ID: {route_id}")
print(f"총 비용: {route.total_estimated_cost}원")
for daily in route.itinerary:
    print(f"\nDay {daily.day_number} ({daily.day_date}):")
    print(f"이동거리: {daily.total_distance}km")
    print(f"비용: {daily.total_estimated_cost}원")
    for activity in daily.activities:
        print(f"  {activity.activity_time} - {activity.activity_name}")

# 7. DB 연결 종료
conn.close()
"""
