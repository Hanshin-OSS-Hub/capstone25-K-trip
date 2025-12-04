from dotenv import load_dotenv
load_dotenv()
from fastapi import FastAPI, HTTPException, Depends, Query
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from pydantic import BaseModel, Field, field_validator
from typing import Optional, List
from datetime import date, datetime
from decimal import Decimal
import mysql.connector
from mysql.connector import Error, pooling
import os
from enum import Enum
import logging

# Logging Configuration
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

app = FastAPI(title="Review API", version="1.0.0")

# CORS Configuration - 프론트엔드 주소에 맞게 수정
app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "http://localhost:3000",  # React 개발 서버
        "http://localhost:5173",  # Vite 개발 서버
        "http://localhost:8080",  # Vue 개발 서버
        # 프로덕션 도메인 추가: "https://yourdomain.com"
    ],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Database Configuration
DB_CONFIG = {
    'host': os.getenv('DB_HOST'),
    'user': os.getenv('DB_USER'),
    'password': os.getenv('DB_PASSWORD'),
    'database': os.getenv('DB_NAME'),
    'charset': 'utf8mb4',
    'collation': 'utf8mb4_unicode_ci'
}

# Connection Pool Configuration
try:
    db_pool = pooling.MySQLConnectionPool(
        pool_name="review_pool",
        pool_size=10,
        pool_reset_session=True,
        **DB_CONFIG
    )
    logger.info("Database connection pool created successfully")
except Error as e:
    logger.error(f"Failed to create connection pool: {str(e)}")
    db_pool = None

# Database Connection Dependency
def get_db():
    """FastAPI dependency for database connection"""
    conn = None
    try:
        if db_pool:
            conn = db_pool.get_connection()
        else:
            conn = mysql.connector.connect(**DB_CONFIG)
        yield conn
    except Error as e:
        logger.error(f"Database connection failed: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Database connection failed: {str(e)}")
    finally:
        if conn and conn.is_connected():
            conn.close()

# Verify required tables exist
def verify_tables():
    """서버 시작 시 필요한 테이블 존재 여부 확인"""
    required_tables = ['users', 'locations', 'reviews', 'review_media', 'review_likes']
    try:
        conn = next(get_db())
        cursor = conn.cursor()
        
        for table in required_tables:
            cursor.execute(f"SHOW TABLES LIKE '{table}'")
            result = cursor.fetchone()
            
            if not result:
                logger.warning(f"⚠️  WARNING: '{table}' table not found in database!")
            else:
                logger.info(f"✓ '{table}' table verified")
        
        cursor.close()
    except Exception as e:
        logger.error(f"Failed to verify tables: {str(e)}")

# Enums
class MediaType(str, Enum):
    photo = "photo"
    video = "video"

class SortBy(str, Enum):
    latest = "latest"
    rating_high = "rating_high"
    rating_low = "rating_low"
    likes = "likes"

# Pydantic Models with v2 validators
class ReviewCreate(BaseModel):
    user_id: int = Field(..., gt=0)
    location_id: int = Field(..., gt=0)
    rating: float = Field(..., ge=1.0, le=5.0)
    review_title: Optional[str] = Field(None, max_length=200)
    review_comment: Optional[str] = Field(None, max_length=5000)
    visit_date: Optional[date] = None

    @field_validator('rating')
    @classmethod
    def validate_rating(cls, v):
        if (v * 2) != int(v * 2):
            raise ValueError('Rating must be in 0.5 increments (e.g., 1.0, 1.5, 2.0)')
        return v
    
    @field_validator('review_title', 'review_comment')
    @classmethod
    def strip_whitespace(cls, v):
        if v is not None and not v.strip():
            raise ValueError('Field cannot be empty or whitespace only')
        return v.strip() if v else v

class ReviewUpdate(BaseModel):
    rating: Optional[float] = Field(None, ge=1.0, le=5.0)
    review_title: Optional[str] = Field(None, max_length=200)
    review_comment: Optional[str] = Field(None, max_length=5000)
    visit_date: Optional[date] = None

    @field_validator('rating')
    @classmethod
    def validate_rating(cls, v):
        if v is not None and (v * 2) != int(v * 2):
            raise ValueError('Rating must be in 0.5 increments')
        return v
    
    @field_validator('review_title', 'review_comment')
    @classmethod
    def strip_whitespace(cls, v):
        if v is not None and not v.strip():
            raise ValueError('Field cannot be empty or whitespace only')
        return v.strip() if v else v

class ReviewMediaCreate(BaseModel):
    media_type: MediaType
    media_url: str = Field(..., max_length=255)
    media_thumbnail_url: Optional[str] = Field(None, max_length=255)
    file_size_bytes: Optional[int] = None
    media_order: int = Field(0, ge=0)

class ReviewResponse(BaseModel):
    review_id: int
    user_id: int
    location_id: int
    rating: float
    review_title: Optional[str]
    review_comment: Optional[str]
    visit_date: Optional[date]
    created_at: datetime
    updated_at: datetime
    total_likes: int
    total_media: int
    photo_count: int
    video_count: int

class ReviewDetailResponse(ReviewResponse):
    media: List[dict] = []

# Startup Event
@app.on_event("startup")
async def startup_event():
    logger.info("🚀 Review API Server Starting...")
    verify_tables()
    logger.info("✓ Server started successfully")

# API Endpoints

@app.get("/")
def read_root():
    return {
        "message": "Review API is running",
        "version": "1.0.0",
        "status": "healthy"
    }

@app.get("/health")
def health_check(conn = Depends(get_db)):
    """헬스 체크 엔드포인트"""
    try:
        cursor = conn.cursor()
        cursor.execute("SELECT 1")
        cursor.fetchone()
        cursor.close()
        return {"status": "healthy", "database": "connected"}
    except Exception as e:
        logger.error(f"Health check failed: {str(e)}")
        return {"status": "unhealthy", "database": "disconnected", "error": str(e)}

# 1. Create Review
@app.post("/reviews", response_model=dict, status_code=201)
def create_review(review: ReviewCreate, conn = Depends(get_db)):
    cursor = conn.cursor()
    
    try:
        # Verify user exists
        cursor.execute("SELECT id FROM users WHERE id = %s", (review.user_id,))
        if not cursor.fetchone():
            raise HTTPException(status_code=404, detail="User not found")
        
        # Verify location exists
        cursor.execute("SELECT location_id FROM locations WHERE location_id = %s", (review.location_id,))
        if not cursor.fetchone():
            raise HTTPException(status_code=404, detail="Location not found")
        
        query = """
        INSERT INTO reviews (user_id, location_id, rating, review_title, review_comment, visit_date)
        VALUES (%s, %s, %s, %s, %s, %s)
        """
        cursor.execute(query, (
            review.user_id,
            review.location_id,
            review.rating,
            review.review_title,
            review.review_comment,
            review.visit_date
        ))
        conn.commit()
        
        review_id = cursor.lastrowid
        logger.info(f"Review created: review_id={review_id}, user_id={review.user_id}, location_id={review.location_id}")
        
        return {
            "message": "Review created successfully",
            "review_id": review_id
        }
    except HTTPException:
        raise
    except Error as e:
        conn.rollback()
        logger.error(f"Failed to create review: {str(e)}")
        raise HTTPException(status_code=400, detail=f"Failed to create review: {str(e)}")
    finally:
        cursor.close()

# 2. Get Review by ID
@app.get("/reviews/{review_id}", response_model=ReviewDetailResponse)
def get_review(review_id: int, conn = Depends(get_db)):
    cursor = conn.cursor(dictionary=True)
    
    try:
        # Get review with stats (like_count calculated from review_likes table)
        query = """
        SELECT 
            r.*,
            COUNT(DISTINCT rl.like_id) AS total_likes,
            COUNT(DISTINCT rm.media_id) AS total_media,
            COUNT(DISTINCT CASE WHEN rm.media_type = 'photo' THEN rm.media_id END) AS photo_count,
            COUNT(DISTINCT CASE WHEN rm.media_type = 'video' THEN rm.media_id END) AS video_count
        FROM reviews r
        LEFT JOIN review_likes rl ON r.review_id = rl.review_id
        LEFT JOIN review_media rm ON r.review_id = rm.review_id
        WHERE r.review_id = %s AND r.is_deleted = FALSE
        GROUP BY r.review_id
        """
        cursor.execute(query, (review_id,))
        review = cursor.fetchone()
        
        if not review:
            raise HTTPException(status_code=404, detail="Review not found")
        
        # Get media
        media_query = """
        SELECT media_id, media_type, media_url, media_thumbnail_url, 
               file_size_bytes, media_order
        FROM review_media
        WHERE review_id = %s
        ORDER BY media_order
        """
        cursor.execute(media_query, (review_id,))
        review['media'] = cursor.fetchall()
        
        return review
    except HTTPException:
        raise
    except Error as e:
        logger.error(f"Failed to get review {review_id}: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Failed to retrieve review: {str(e)}")
    finally:
        cursor.close()

# 3. Get Reviews by Location
@app.get("/locations/{location_id}/reviews")
def get_reviews_by_location(
    location_id: int,
    page: int = Query(1, ge=1),
    limit: int = Query(10, ge=1, le=100),
    sort_by: SortBy = SortBy.latest,
    min_rating: Optional[float] = Query(None, ge=1.0, le=5.0),
    conn = Depends(get_db)
):
    cursor = conn.cursor(dictionary=True)
    
    try:
        offset = (page - 1) * limit
        
        # Build WHERE conditions
        where_conditions = ["r.location_id = %s", "r.is_deleted = FALSE"]
        params = [location_id]
        
        if min_rating:
            where_conditions.append("r.rating >= %s")
            params.append(min_rating)
        
        where_clause = " AND ".join(where_conditions)
        
        # Build ORDER BY clause (safe - enum values)
        order_mapping = {
            SortBy.latest: "r.created_at DESC",
            SortBy.rating_high: "r.rating DESC, r.created_at DESC",
            SortBy.rating_low: "r.rating ASC, r.created_at DESC",
            SortBy.likes: "total_likes DESC, r.created_at DESC"
        }
        order_clause = order_mapping[sort_by]
        
        # Main query - like_count calculated from review_likes table
        query = f"""
        SELECT 
            r.*,
            COUNT(DISTINCT rl.like_id) AS total_likes,
            COUNT(DISTINCT rm.media_id) AS total_media,
            COUNT(DISTINCT CASE WHEN rm.media_type = 'photo' THEN rm.media_id END) AS photo_count,
            COUNT(DISTINCT CASE WHEN rm.media_type = 'video' THEN rm.media_id END) AS video_count
        FROM reviews r
        LEFT JOIN review_likes rl ON r.review_id = rl.review_id
        LEFT JOIN review_media rm ON r.review_id = rm.review_id
        WHERE {where_clause}
        GROUP BY r.review_id
        ORDER BY {order_clause}
        LIMIT %s OFFSET %s
        """
        params.extend([limit, offset])
        
        cursor.execute(query, params)
        reviews = cursor.fetchall()
        
        # Get total count
        count_query = f"""
        SELECT COUNT(DISTINCT r.review_id) as total
        FROM reviews r
        WHERE {where_clause}
        """
        cursor.execute(count_query, params[:-2])
        total = cursor.fetchone()['total']
        
        total_pages = (total + limit - 1) // limit
        
        return {
            "reviews": reviews,
            "pagination": {
                "page": page,
                "limit": limit,
                "total": total,
                "total_pages": total_pages,
                "has_next": page < total_pages,
                "has_prev": page > 1
            }
        }
    except Error as e:
        logger.error(f"Failed to get reviews for location {location_id}: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Failed to retrieve reviews: {str(e)}")
    finally:
        cursor.close()

# 4. Get Reviews by User
@app.get("/users/{user_id}/reviews")
def get_reviews_by_user(
    user_id: int,
    page: int = Query(1, ge=1),
    limit: int = Query(10, ge=1, le=100),
    conn = Depends(get_db)
):
    cursor = conn.cursor(dictionary=True)
    
    try:
        offset = (page - 1) * limit
        
        query = """
        SELECT 
            r.*,
            COUNT(DISTINCT rl.like_id) AS total_likes,
            COUNT(DISTINCT rm.media_id) AS total_media,
            COUNT(DISTINCT CASE WHEN rm.media_type = 'photo' THEN rm.media_id END) AS photo_count,
            COUNT(DISTINCT CASE WHEN rm.media_type = 'video' THEN rm.media_id END) AS video_count
        FROM reviews r
        LEFT JOIN review_likes rl ON r.review_id = rl.review_id
        LEFT JOIN review_media rm ON r.review_id = rm.review_id
        WHERE r.user_id = %s AND r.is_deleted = FALSE
        GROUP BY r.review_id
        ORDER BY r.created_at DESC
        LIMIT %s OFFSET %s
        """
        cursor.execute(query, (user_id, limit, offset))
        reviews = cursor.fetchall()
        
        # Get total count
        cursor.execute(
            "SELECT COUNT(*) as total FROM reviews WHERE user_id = %s AND is_deleted = FALSE",
            (user_id,)
        )
        total = cursor.fetchone()['total']
        
        total_pages = (total + limit - 1) // limit
        
        return {
            "reviews": reviews,
            "pagination": {
                "page": page,
                "limit": limit,
                "total": total,
                "total_pages": total_pages,
                "has_next": page < total_pages,
                "has_prev": page > 1
            }
        }
    except Error as e:
        logger.error(f"Failed to get reviews for user {user_id}: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Failed to retrieve reviews: {str(e)}")
    finally:
        cursor.close()

# 5. Update Review
@app.put("/reviews/{review_id}")
def update_review(review_id: int, review_update: ReviewUpdate, user_id: int = Query(...), conn = Depends(get_db)):
    cursor = conn.cursor()
    
    try:
        # Check if review exists and belongs to user
        cursor.execute("SELECT user_id FROM reviews WHERE review_id = %s AND is_deleted = FALSE", (review_id,))
        result = cursor.fetchone()
        
        if not result:
            raise HTTPException(status_code=404, detail="Review not found")
        
        if result[0] != user_id:
            raise HTTPException(status_code=403, detail="Not authorized to update this review")
        
        # Build update query
        update_fields = []
        params = []
        
        if review_update.rating is not None:
            update_fields.append("rating = %s")
            params.append(review_update.rating)
        
        if review_update.review_title is not None:
            update_fields.append("review_title = %s")
            params.append(review_update.review_title)
        
        if review_update.review_comment is not None:
            update_fields.append("review_comment = %s")
            params.append(review_update.review_comment)
        
        if review_update.visit_date is not None:
            update_fields.append("visit_date = %s")
            params.append(review_update.visit_date)
        
        if not update_fields:
            raise HTTPException(status_code=400, detail="No fields to update")
        
        query = f"""
        UPDATE reviews
        SET {', '.join(update_fields)}
        WHERE review_id = %s
        """
        params.append(review_id)
        
        cursor.execute(query, params)
        conn.commit()
        
        logger.info(f"Review updated: review_id={review_id}, user_id={user_id}")
        
        return {"message": "Review updated successfully"}
    except HTTPException:
        raise
    except Error as e:
        conn.rollback()
        logger.error(f"Failed to update review {review_id}: {str(e)}")
        raise HTTPException(status_code=400, detail=f"Failed to update review: {str(e)}")
    finally:
        cursor.close()

# 6. Delete Review (Soft Delete)
@app.delete("/reviews/{review_id}")
def delete_review(review_id: int, user_id: int = Query(...), conn = Depends(get_db)):
    cursor = conn.cursor()
    
    try:
        # Check if review exists and belongs to user
        cursor.execute("SELECT user_id FROM reviews WHERE review_id = %s AND is_deleted = FALSE", (review_id,))
        result = cursor.fetchone()
        
        if not result:
            raise HTTPException(status_code=404, detail="Review not found")
        
        if result[0] != user_id:
            raise HTTPException(status_code=403, detail="Not authorized to delete this review")
        
        cursor.execute("UPDATE reviews SET is_deleted = TRUE WHERE review_id = %s", (review_id,))
        conn.commit()
        
        logger.info(f"Review deleted: review_id={review_id}, user_id={user_id}")
        
        return {"message": "Review deleted successfully"}
    except HTTPException:
        raise
    except Error as e:
        conn.rollback()
        logger.error(f"Failed to delete review {review_id}: {str(e)}")
        raise HTTPException(status_code=400, detail=f"Failed to delete review: {str(e)}")
    finally:
        cursor.close()

# 7. Add Media to Review
@app.post("/reviews/{review_id}/media")
def add_review_media(review_id: int, media: ReviewMediaCreate, user_id: int = Query(...), conn = Depends(get_db)):
    cursor = conn.cursor()
    
    try:
        # Check if review exists and belongs to user
        cursor.execute("SELECT user_id FROM reviews WHERE review_id = %s AND is_deleted = FALSE", (review_id,))
        result = cursor.fetchone()
        
        if not result:
            raise HTTPException(status_code=404, detail="Review not found")
        
        if result[0] != user_id:
            raise HTTPException(status_code=403, detail="Not authorized to add media to this review")
        
        query = """
        INSERT INTO review_media (review_id, media_type, media_url, media_thumbnail_url, file_size_bytes, media_order)
        VALUES (%s, %s, %s, %s, %s, %s)
        """
        cursor.execute(query, (
            review_id,
            media.media_type.value,
            media.media_url,
            media.media_thumbnail_url,
            media.file_size_bytes,
            media.media_order
        ))
        conn.commit()
        
        media_id = cursor.lastrowid
        logger.info(f"Media added: media_id={media_id}, review_id={review_id}")
        
        return {
            "message": "Media added successfully",
            "media_id": media_id
        }
    except HTTPException:
        raise
    except Error as e:
        conn.rollback()
        logger.error(f"Failed to add media: {str(e)}")
        raise HTTPException(status_code=400, detail=f"Failed to add media: {str(e)}")
    finally:
        cursor.close()

# 8. Like Review
@app.post("/reviews/{review_id}/like")
def like_review(review_id: int, user_id: int = Query(...), conn = Depends(get_db)):
    cursor = conn.cursor()
    
    try:
        # Check if review exists
        cursor.execute("SELECT review_id FROM reviews WHERE review_id = %s AND is_deleted = FALSE", (review_id,))
        if not cursor.fetchone():
            raise HTTPException(status_code=404, detail="Review not found")
        
        # Try to insert like
        try:
            cursor.execute(
                "INSERT INTO review_likes (review_id, user_id) VALUES (%s, %s)",
                (review_id, user_id)
            )
            conn.commit()
            
            logger.info(f"Review liked: review_id={review_id}, user_id={user_id}")
            return {"message": "Review liked successfully"}
        except mysql.connector.IntegrityError:
            raise HTTPException(status_code=400, detail="You have already liked this review")
    except HTTPException:
        raise
    except Error as e:
        conn.rollback()
        logger.error(f"Failed to like review {review_id}: {str(e)}")
        raise HTTPException(status_code=400, detail=f"Failed to like review: {str(e)}")
    finally:
        cursor.close()

# 9. Unlike Review
@app.delete("/reviews/{review_id}/like")
def unlike_review(review_id: int, user_id: int = Query(...), conn = Depends(get_db)):
    cursor = conn.cursor()
    
    try:
        cursor.execute(
            "DELETE FROM review_likes WHERE review_id = %s AND user_id = %s",
            (review_id, user_id)
        )
        
        if cursor.rowcount == 0:
            raise HTTPException(status_code=404, detail="Like not found")
        
        conn.commit()
        
        logger.info(f"Review unliked: review_id={review_id}, user_id={user_id}")
        return {"message": "Review unliked successfully"}
    except HTTPException:
        raise
    except Error as e:
        conn.rollback()
        logger.error(f"Failed to unlike review {review_id}: {str(e)}")
        raise HTTPException(status_code=400, detail=f"Failed to unlike review: {str(e)}")
    finally:
        cursor.close()

# 10. Get Location Statistics
@app.get("/locations/{location_id}/stats")
def get_location_stats(location_id: int, conn = Depends(get_db)):
    cursor = conn.cursor(dictionary=True)
    
    try:
        # Get statistics - like_count calculated from review_likes table
        query = """
        SELECT 
            COUNT(DISTINCT r.review_id) as total_reviews,
            AVG(r.rating) as average_rating,
            SUM(CASE WHEN r.rating >= 4.0 THEN 1 ELSE 0 END) as positive_reviews,
            COUNT(DISTINCT rl.like_id) as total_likes
        FROM reviews r
        LEFT JOIN review_likes rl ON r.review_id = rl.review_id
        WHERE r.location_id = %s AND r.is_deleted = FALSE
        """
        cursor.execute(query, (location_id,))
        stats = cursor.fetchone()
        
        # Get rating distribution
        rating_query = """
        SELECT 
            rating,
            COUNT(*) as count
        FROM reviews
        WHERE location_id = %s AND is_deleted = FALSE
        GROUP BY rating
        ORDER BY rating DESC
        """
        cursor.execute(rating_query, (location_id,))
        rating_distribution = cursor.fetchall()
        
        return {
            "location_id": location_id,
            "statistics": stats,
            "rating_distribution": rating_distribution
        }
    except Error as e:
        logger.error(f"Failed to get stats for location {location_id}: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Failed to retrieve statistics: {str(e)}")
    finally:
        cursor.close()

if __name__ == "__main__":
    import uvicorn

    uvicorn.run(app, host="0.0.0.0", port=8000)
