from fastapi import FastAPI, HTTPException, Depends, Query, UploadFile, File
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from pydantic import BaseModel, Field, validator
from typing import Optional, List
from datetime import datetime
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

app = FastAPI(title="Board API", version="1.0.0")

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

# Database Configuration - 실제 DB 정보로 수정
DB_CONFIG = {
    'host': os.getenv('DB_HOST', 'localhost'),
    'user': os.getenv('DB_USER', 'root'),
    'password': os.getenv('DB_PASSWORD', ''),  # 실제 비밀번호 입력
    'database': os.getenv('DB_NAME', 'your_database'),  # 실제 DB 이름 입력
    'charset': 'utf8mb4',
    'collation': 'utf8mb4_unicode_ci'
}

# Connection Pool Configuration
try:
    db_pool = pooling.MySQLConnectionPool(
        pool_name="board_pool",
        pool_size=10,
        pool_reset_session=True,
        **DB_CONFIG
    )
    logger.info("Database connection pool created successfully")
except Error as e:
    logger.error(f"Failed to create connection pool: {str(e)}")
    db_pool = None

# Database Connection with Connection Pool
def get_db_connection():
    try:
        if db_pool:
            conn = db_pool.get_connection()
        else:
            conn = mysql.connector.connect(**DB_CONFIG)
        return conn
    except Error as e:
        logger.error(f"Database connection failed: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Database connection failed: {str(e)}")

# Verify users table exists
def verify_users_table():
    """서버 시작 시 users 테이블 존재 여부 확인"""
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("SHOW TABLES LIKE 'users'")
        result = cursor.fetchone()
        cursor.close()
        conn.close()
        
        if not result:
            logger.warning("⚠️  WARNING: 'users' table not found in database!")
            logger.warning("⚠️  Foreign key constraints may fail. Please create users table.")
        else:
            logger.info("✓ 'users' table verified")
    except Exception as e:
        logger.error(f"Failed to verify users table: {str(e)}")

# Enums
class Language(str, Enum):
    ko = "ko"
    en = "en"
    ja = "ja"
    zh = "zh"

class SortBy(str, Enum):
    latest = "latest"
    oldest = "oldest"
    likes = "likes"

# Pydantic Models
class PostCreate(BaseModel):
    user_id: int = Field(..., gt=0)
    region_id: Optional[int] = None
    category_id: Optional[int] = None
    title: str = Field(..., max_length=200, min_length=1)
    content: str = Field(..., min_length=1, max_length=10000)
    is_public: bool = True
    
    @validator('title', 'content')
    def strip_whitespace(cls, v):
        if not v.strip():
            raise ValueError('Field cannot be empty or whitespace only')
        return v.strip()

class PostUpdate(BaseModel):
    region_id: Optional[int] = None
    category_id: Optional[int] = None
    title: Optional[str] = Field(None, max_length=200, min_length=1)
    content: Optional[str] = Field(None, min_length=1, max_length=10000)
    is_public: Optional[bool] = None
    
    @validator('title', 'content')
    def strip_whitespace(cls, v):
        if v is not None and not v.strip():
            raise ValueError('Field cannot be empty or whitespace only')
        return v.strip() if v else v

class PostResponse(BaseModel):
    post_id: int
    user_id: int
    region_id: Optional[int]
    category_id: Optional[int]
    title: str
    content: str
    is_public: bool
    created_at: datetime
    updated_at: datetime
    like_count: int = 0
    comment_count: int = 0

class CommentCreate(BaseModel):
    user_id: int = Field(..., gt=0)
    content: str = Field(..., min_length=1, max_length=1000)
    parent_comment_id: Optional[int] = None
    
    @validator('content')
    def strip_whitespace(cls, v):
        if not v.strip():
            raise ValueError('Content cannot be empty or whitespace only')
        return v.strip()

class CommentUpdate(BaseModel):
    content: str = Field(..., min_length=1, max_length=1000)
    
    @validator('content')
    def strip_whitespace(cls, v):
        if not v.strip():
            raise ValueError('Content cannot be empty or whitespace only')
        return v.strip()

class CommentResponse(BaseModel):
    comment_id: int
    post_id: int
    user_id: int
    parent_comment_id: Optional[int]
    content: str
    created_at: datetime
    replies: List[dict] = []

class TranslationCreate(BaseModel):
    language: Language
    translated_title: str = Field(..., max_length=200)
    translated_content: str
    translation_engine: str = Field(default="gpt", max_length=50)
    is_auto: bool = True

class ImageCreate(BaseModel):
    image_url: str = Field(..., max_length=500)
    is_primary: bool = False

# Startup Event
@app.on_event("startup")
async def startup_event():
    logger.info("🚀 Board API Server Starting...")
    verify_users_table()
    logger.info("✓ Server started successfully")

# API Endpoints

@app.get("/")
def read_root():
    return {
        "message": "Board API is running",
        "version": "1.0.0",
        "status": "healthy"
    }

@app.get("/health")
def health_check():
    """헬스 체크 엔드포인트"""
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("SELECT 1")
        cursor.fetchone()
        cursor.close()
        conn.close()
        return {"status": "healthy", "database": "connected"}
    except Exception as e:
        logger.error(f"Health check failed: {str(e)}")
        return {"status": "unhealthy", "database": "disconnected", "error": str(e)}

# ==================== POST ENDPOINTS ====================

# 1. Create Post
@app.post("/posts", response_model=dict, status_code=201)
def create_post(post: PostCreate):
    conn = get_db_connection()
    cursor = conn.cursor()
    
    try:
        # Verify user exists
        cursor.execute("SELECT id FROM users WHERE id = %s", (post.user_id,))
        if not cursor.fetchone():
            raise HTTPException(status_code=404, detail="User not found")
        
        query = """
        INSERT INTO board_posts (user_id, region_id, category_id, title, content, is_public)
        VALUES (%s, %s, %s, %s, %s, %s)
        """
        cursor.execute(query, (
            post.user_id,
            post.region_id,
            post.category_id,
            post.title,
            post.content,
            post.is_public
        ))
        conn.commit()
        
        post_id = cursor.lastrowid
        logger.info(f"Post created: post_id={post_id}, user_id={post.user_id}")
        
        return {
            "message": "Post created successfully",
            "post_id": post_id
        }
    except HTTPException:
        raise
    except Error as e:
        conn.rollback()
        logger.error(f"Failed to create post: {str(e)}")
        raise HTTPException(status_code=400, detail=f"Failed to create post: {str(e)}")
    finally:
        cursor.close()
        conn.close()

# 2. Get Post by ID
@app.get("/posts/{post_id}")
def get_post(post_id: int, language: Optional[Language] = None):
    conn = get_db_connection()
    cursor = conn.cursor(dictionary=True)
    
    try:
        query = """
        SELECT p.*,
               (SELECT COUNT(*) FROM board_post_likes WHERE post_id = p.post_id) as like_count,
               (SELECT COUNT(*) FROM board_comments WHERE post_id = p.post_id AND is_deleted = FALSE) as comment_count
        FROM board_posts p
        WHERE p.post_id = %s AND p.is_deleted = FALSE
        """
        cursor.execute(query, (post_id,))
        post = cursor.fetchone()
        
        if not post:
            raise HTTPException(status_code=404, detail="Post not found")
        
        # Get translation if language specified
        if language:
            trans_query = """
            SELECT translated_title, translated_content
            FROM board_post_translations
            WHERE post_id = %s AND language = %s
            """
            cursor.execute(trans_query, (post_id, language.value))
            translation = cursor.fetchone()
            
            if translation:
                post['translated_title'] = translation['translated_title']
                post['translated_content'] = translation['translated_content']
        
        # Get images
        image_query = """
        SELECT image_id, image_url, is_primary, uploaded_at
        FROM board_post_images
        WHERE post_id = %s
        ORDER BY is_primary DESC, uploaded_at ASC
        """
        cursor.execute(image_query, (post_id,))
        post['images'] = cursor.fetchall()
        
        return post
    except HTTPException:
        raise
    except Error as e:
        logger.error(f"Failed to get post {post_id}: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Failed to retrieve post: {str(e)}")
    finally:
        cursor.close()
        conn.close()

# 3. Get Posts List
@app.get("/posts")
def get_posts(
    page: int = Query(1, ge=1),
    limit: int = Query(20, ge=1, le=100),
    region_id: Optional[int] = None,
    category_id: Optional[int] = None,
    user_id: Optional[int] = None,
    sort_by: SortBy = SortBy.latest,
    search: Optional[str] = None,
    language: Optional[Language] = None
):
    conn = get_db_connection()
    cursor = conn.cursor(dictionary=True)
    
    try:
        offset = (page - 1) * limit
        
        where_conditions = ["p.is_deleted = FALSE", "p.is_public = TRUE"]
        params = []
        
        if region_id:
            where_conditions.append("p.region_id = %s")
            params.append(region_id)
        
        if category_id:
            where_conditions.append("p.category_id = %s")
            params.append(category_id)
        
        if user_id:
            where_conditions.append("p.user_id = %s")
            params.append(user_id)
        
        if search:
            where_conditions.append("(p.title LIKE %s OR p.content LIKE %s)")
            search_pattern = f"%{search}%"
            params.extend([search_pattern, search_pattern])
        
        where_clause = " AND ".join(where_conditions)
        
        order_clause = {
            "latest": "p.created_at DESC",
            "oldest": "p.created_at ASC",
            "likes": "like_count DESC, p.created_at DESC"
        }[sort_by]
        
        query = f"""
        SELECT p.*,
               (SELECT COUNT(*) FROM board_post_likes WHERE post_id = p.post_id) as like_count,
               (SELECT COUNT(*) FROM board_comments WHERE post_id = p.post_id AND is_deleted = FALSE) as comment_count,
               (SELECT image_url FROM board_post_images WHERE post_id = p.post_id AND is_primary = TRUE LIMIT 1) as primary_image
        FROM board_posts p
        WHERE {where_clause}
        ORDER BY {order_clause}
        LIMIT %s OFFSET %s
        """
        params.extend([limit, offset])
        
        cursor.execute(query, params)
        posts = cursor.fetchall()
        
        # Add translations if language specified
        if language and posts:
            post_ids = [post['post_id'] for post in posts]
            placeholders = ','.join(['%s'] * len(post_ids))
            
            trans_query = f"""
            SELECT post_id, translated_title, translated_content
            FROM board_post_translations
            WHERE post_id IN ({placeholders}) AND language = %s
            """
            cursor.execute(trans_query, post_ids + [language.value])
            translations = {t['post_id']: t for t in cursor.fetchall()}
            
            for post in posts:
                if post['post_id'] in translations:
                    trans = translations[post['post_id']]
                    post['translated_title'] = trans['translated_title']
                    post['translated_content'] = trans['translated_content']
        
        # Get total count
        count_query = f"""
        SELECT COUNT(*) as total
        FROM board_posts p
        WHERE {where_clause}
        """
        cursor.execute(count_query, params[:-2])
        total = cursor.fetchone()['total']
        
        total_pages = (total + limit - 1) // limit
        
        return {
            "posts": posts,
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
        logger.error(f"Failed to get posts: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Failed to retrieve posts: {str(e)}")
    finally:
        cursor.close()
        conn.close()

# 4. Update Post
@app.put("/posts/{post_id}")
def update_post(post_id: int, post_update: PostUpdate, user_id: int = Query(...)):
    conn = get_db_connection()
    cursor = conn.cursor()
    
    try:
        cursor.execute("SELECT user_id FROM board_posts WHERE post_id = %s AND is_deleted = FALSE", (post_id,))
        result = cursor.fetchone()
        
        if not result:
            raise HTTPException(status_code=404, detail="Post not found")
        
        if result[0] != user_id:
            raise HTTPException(status_code=403, detail="Not authorized to update this post")
        
        update_fields = []
        params = []
        
        if post_update.region_id is not None:
            update_fields.append("region_id = %s")
            params.append(post_update.region_id)
        
        if post_update.category_id is not None:
            update_fields.append("category_id = %s")
            params.append(post_update.category_id)
        
        if post_update.title is not None:
            update_fields.append("title = %s")
            params.append(post_update.title)
        
        if post_update.content is not None:
            update_fields.append("content = %s")
            params.append(post_update.content)
        
        if post_update.is_public is not None:
            update_fields.append("is_public = %s")
            params.append(post_update.is_public)
        
        if not update_fields:
            raise HTTPException(status_code=400, detail="No fields to update")
        
        query = f"""
        UPDATE board_posts
        SET {', '.join(update_fields)}
        WHERE post_id = %s
        """
        params.append(post_id)
        
        cursor.execute(query, params)
        conn.commit()
        
        logger.info(f"Post updated: post_id={post_id}, user_id={user_id}")
        
        return {"message": "Post updated successfully"}
    except HTTPException:
        raise
    except Error as e:
        conn.rollback()
        logger.error(f"Failed to update post {post_id}: {str(e)}")
        raise HTTPException(status_code=400, detail=f"Failed to update post: {str(e)}")
    finally:
        cursor.close()
        conn.close()

# 5. Delete Post (Soft Delete)
@app.delete("/posts/{post_id}")
def delete_post(post_id: int, user_id: int = Query(...)):
    conn = get_db_connection()
    cursor = conn.cursor()
    
    try:
        cursor.execute("SELECT user_id FROM board_posts WHERE post_id = %s AND is_deleted = FALSE", (post_id,))
        result = cursor.fetchone()
        
        if not result:
            raise HTTPException(status_code=404, detail="Post not found")
        
        if result[0] != user_id:
            raise HTTPException(status_code=403, detail="Not authorized to delete this post")
        
        cursor.execute("UPDATE board_posts SET is_deleted = TRUE WHERE post_id = %s", (post_id,))
        conn.commit()
        
        logger.info(f"Post deleted: post_id={post_id}, user_id={user_id}")
        
        return {"message": "Post deleted successfully"}
    except HTTPException:
        raise
    except Error as e:
        conn.rollback()
        logger.error(f"Failed to delete post {post_id}: {str(e)}")
        raise HTTPException(status_code=400, detail=f"Failed to delete post: {str(e)}")
    finally:
        cursor.close()
        conn.close()

# 6. Like Post
@app.post("/posts/{post_id}/like")
def like_post(post_id: int, user_id: int = Query(...)):
    conn = get_db_connection()
    cursor = conn.cursor()
    
    try:
        cursor.execute("SELECT post_id FROM board_posts WHERE post_id = %s AND is_deleted = FALSE", (post_id,))
        if not cursor.fetchone():
            raise HTTPException(status_code=404, detail="Post not found")
        
        try:
            cursor.execute(
                "INSERT INTO board_post_likes (post_id, user_id) VALUES (%s, %s)",
                (post_id, user_id)
            )
            conn.commit()
            logger.info(f"Post liked: post_id={post_id}, user_id={user_id}")
            return {"message": "Post liked successfully"}
        except mysql.connector.IntegrityError:
            raise HTTPException(status_code=400, detail="You have already liked this post")
    except HTTPException:
        raise
    except Error as e:
        conn.rollback()
        logger.error(f"Failed to like post {post_id}: {str(e)}")
        raise HTTPException(status_code=400, detail=f"Failed to like post: {str(e)}")
    finally:
        cursor.close()
        conn.close()

# 7. Unlike Post
@app.delete("/posts/{post_id}/like")
def unlike_post(post_id: int, user_id: int = Query(...)):
    conn = get_db_connection()
    cursor = conn.cursor()
    
    try:
        cursor.execute(
            "DELETE FROM board_post_likes WHERE post_id = %s AND user_id = %s",
            (post_id, user_id)
        )
        
        if cursor.rowcount == 0:
            raise HTTPException(status_code=404, detail="Like not found")
        
        conn.commit()
        logger.info(f"Post unliked: post_id={post_id}, user_id={user_id}")
        return {"message": "Post unliked successfully"}
    except HTTPException:
        raise
    except Error as e:
        conn.rollback()
        logger.error(f"Failed to unlike post {post_id}: {str(e)}")
        raise HTTPException(status_code=400, detail=f"Failed to unlike post: {str(e)}")
    finally:
        cursor.close()
        conn.close()

# ==================== COMMENT ENDPOINTS ====================

# 8. Create Comment
@app.post("/posts/{post_id}/comments", status_code=201)
def create_comment(post_id: int, comment: CommentCreate):
    conn = get_db_connection()
    cursor = conn.cursor()
    
    try:
        cursor.execute("SELECT post_id FROM board_posts WHERE post_id = %s AND is_deleted = FALSE", (post_id,))
        if not cursor.fetchone():
            raise HTTPException(status_code=404, detail="Post not found")
        
        if comment.parent_comment_id:
            cursor.execute(
                "SELECT comment_id FROM board_comments WHERE comment_id = %s AND post_id = %s AND is_deleted = FALSE",
                (comment.parent_comment_id, post_id)
            )
            if not cursor.fetchone():
                raise HTTPException(status_code=404, detail="Parent comment not found")
        
        query = """
        INSERT INTO board_comments (post_id, user_id, parent_comment_id, content)
        VALUES (%s, %s, %s, %s)
        """
        cursor.execute(query, (post_id, comment.user_id, comment.parent_comment_id, comment.content))
        conn.commit()
        
        comment_id = cursor.lastrowid
        logger.info(f"Comment created: comment_id={comment_id}, post_id={post_id}, user_id={comment.user_id}")
        
        return {
            "message": "Comment created successfully",
            "comment_id": comment_id
        }
    except HTTPException:
        raise
    except Error as e:
        conn.rollback()
        logger.error(f"Failed to create comment: {str(e)}")
        raise HTTPException(status_code=400, detail=f"Failed to create comment: {str(e)}")
    finally:
        cursor.close()
        conn.close()

# 9. Get Comments by Post
@app.get("/posts/{post_id}/comments")
def get_comments(post_id: int):
    conn = get_db_connection()
    cursor = conn.cursor(dictionary=True)
    
    try:
        query = """
        SELECT comment_id, post_id, user_id, parent_comment_id, content, created_at
        FROM board_comments
        WHERE post_id = %s AND is_deleted = FALSE
        ORDER BY created_at ASC
        """
        cursor.execute(query, (post_id,))
        all_comments = cursor.fetchall()
        
        comment_dict = {c['comment_id']: {**c, 'replies': []} for c in all_comments}
        root_comments = []
        
        for comment in all_comments:
            if comment['parent_comment_id'] is None:
                root_comments.append(comment_dict[comment['comment_id']])
            else:
                parent = comment_dict.get(comment['parent_comment_id'])
                if parent:
                    parent['replies'].append(comment_dict[comment['comment_id']])
        
        return {
            "comments": root_comments,
            "total_count": len(all_comments)
        }
    except Error as e:
        logger.error(f"Failed to get comments for post {post_id}: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Failed to retrieve comments: {str(e)}")
    finally:
        cursor.close()
        conn.close()

# 10. Update Comment
@app.put("/posts/{post_id}/comments/{comment_id}")
def update_comment(post_id: int, comment_id: int, comment_update: CommentUpdate, user_id: int = Query(...)):
    conn = get_db_connection()
    cursor = conn.cursor()
    
    try:
        cursor.execute(
            "SELECT user_id FROM board_comments WHERE comment_id = %s AND post_id = %s AND is_deleted = FALSE",
            (comment_id, post_id)
        )
        result = cursor.fetchone()
        
        if not result:
            raise HTTPException(status_code=404, detail="Comment not found")
        
        if result[0] != user_id:
            raise HTTPException(status_code=403, detail="Not authorized to update this comment")
        
        cursor.execute(
            "UPDATE board_comments SET content = %s WHERE comment_id = %s",
            (comment_update.content, comment_id)
        )
        conn.commit()
        
        logger.info(f"Comment updated: comment_id={comment_id}, user_id={user_id}")
        
        return {"message": "Comment updated successfully"}
    except HTTPException:
        raise
    except Error as e:
        conn.rollback()
        logger.error(f"Failed to update comment {comment_id}: {str(e)}")
        raise HTTPException(status_code=400, detail=f"Failed to update comment: {str(e)}")
    finally:
        cursor.close()
        conn.close()

# 11. Delete Comment (Soft Delete)
@app.delete("/posts/{post_id}/comments/{comment_id}")
def delete_comment(post_id: int, comment_id: int, user_id: int = Query(...)):
    conn = get_db_connection()
    cursor = conn.cursor()
    
    try:
        cursor.execute(
            "SELECT user_id FROM board_comments WHERE comment_id = %s AND post_id = %s AND is_deleted = FALSE",
            (comment_id, post_id)
        )
        result = cursor.fetchone()
        
        if not result:
            raise HTTPException(status_code=404, detail="Comment not found")
        
        if result[0] != user_id:
            raise HTTPException(status_code=403, detail="Not authorized to delete this comment")
        
        cursor.execute("UPDATE board_comments SET is_deleted = TRUE WHERE comment_id = %s", (comment_id,))
        conn.commit()
        
        logger.info(f"Comment deleted: comment_id={comment_id}, user_id={user_id}")
        
        return {"message": "Comment deleted successfully"}
    except HTTPException:
        raise
    except Error as e:
        conn.rollback()
        logger.error(f"Failed to delete comment {comment_id}: {str(e)}")
        raise HTTPException(status_code=400, detail=f"Failed to delete comment: {str(e)}")
    finally:
        cursor.close()
        conn.close()

# ==================== TRANSLATION ENDPOINTS ====================

# 12. Add Translation
@app.post("/posts/{post_id}/translations")
def add_translation(post_id: int, translation: TranslationCreate):
    conn = get_db_connection()
    cursor = conn.cursor()
    
    try:
        cursor.execute("SELECT post_id FROM board_posts WHERE post_id = %s AND is_deleted = FALSE", (post_id,))
        if not cursor.fetchone():
            raise HTTPException(status_code=404, detail="Post not found")
        
        query = """
        INSERT INTO board_post_translations 
        (post_id, language, translated_title, translated_content, translation_engine, is_auto)
        VALUES (%s, %s, %s, %s, %s, %s)
        ON DUPLICATE KEY UPDATE
        translated_title = VALUES(translated_title),
        translated_content = VALUES(translated_content),
        translation_engine = VALUES(translation_engine),
        is_auto = VALUES(is_auto),
        translated_at = CURRENT_TIMESTAMP
        """
        cursor.execute(query, (
            post_id,
            translation.language.value,
            translation.translated_title,
            translation.translated_content,
            translation.translation_engine,
            translation.is_auto
        ))
        conn.commit()
        
        logger.info(f"Translation added: post_id={post_id}, language={translation.language.value}")
        
        return {"message": "Translation added successfully"}
    except HTTPException:
        raise
    except Error as e:
        conn.rollback()
        logger.error(f"Failed to add translation: {str(e)}")
        raise HTTPException(status_code=400, detail=f"Failed to add translation: {str(e)}")
    finally:
        cursor.close()
        conn.close()

# 13. Get Translations
@app.get("/posts/{post_id}/translations")
def get_translations(post_id: int):
    conn = get_db_connection()
    cursor = conn.cursor(dictionary=True)
    
    try:
        query = """
        SELECT translation_id, language, translated_title, translated_content, 
               translation_engine, is_auto, translated_at
        FROM board_post_translations
        WHERE post_id = %s
        """
        cursor.execute(query, (post_id,))
        translations = cursor.fetchall()
        
        return {"translations": translations}
    except Error as e:
        logger.error(f"Failed to get translations: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Failed to retrieve translations: {str(e)}")
    finally:
        cursor.close()
        conn.close()

# ==================== IMAGE ENDPOINTS ====================

# 14. Add Image to Post
@app.post("/posts/{post_id}/images")
def add_image(post_id: int, image: ImageCreate, user_id: int = Query(...)):
    conn = get_db_connection()
    cursor = conn.cursor()
    
    try:
        cursor.execute("SELECT user_id FROM board_posts WHERE post_id = %s AND is_deleted = FALSE", (post_id,))
        result = cursor.fetchone()
        
        if not result:
            raise HTTPException(status_code=404, detail="Post not found")
        
        if result[0] != user_id:
            raise HTTPException(status_code=403, detail="Not authorized to add image to this post")
        
        if image.is_primary:
            cursor.execute("UPDATE board_post_images SET is_primary = FALSE WHERE post_id = %s", (post_id,))
        
        query = """
        INSERT INTO board_post_images (post_id, image_url, is_primary)
        VALUES (%s, %s, %s)
        """
        cursor.execute(query, (post_id, image.image_url, image.is_primary))
        conn.commit()
        
        image_id = cursor.lastrowid
        logger.info(f"Image added: image_id={image_id}, post_id={post_id}")
        
        return {
            "message": "Image added successfully",
            "image_id": image_id
        }
    except HTTPException:
        raise
    except Error as e:
        conn.rollback()
        logger.error(f"Failed to add image: {str(e)}")
        raise HTTPException(status_code=400, detail=f"Failed to add image: {str(e)}")
    finally:
        cursor.close()
        conn.close()

# 15. Delete Image
@app.delete("/posts/{post_id}/images/{image_id}")
def delete_image(post_id: int, image_id: int, user_id: int = Query(...)):
    conn = get_db_connection()
    cursor = conn.cursor()
    
    try:
        cursor.execute(
            """
            SELECT p.user_id 
            FROM board_posts p
            JOIN board_post_images i ON p.post_id = i.post_id
            WHERE p.post_id = %s AND i.image_id = %s AND p.is_deleted = FALSE
            """,
            (post_id, image_id)
        )
        result = cursor.fetchone()
        
        if not result:
            raise HTTPException(status_code=404, detail="Image not found")
        
        if result[0] != user_id:
            raise HTTPException(status_code=403, detail="Not authorized to delete this image")
        
        cursor.execute("DELETE FROM board_post_images WHERE image_id = %s", (image_id,))
        conn.commit()
        
        logger.info(f"Image deleted: image_id={image_id}, post_id={post_id}")
        
        return {"message": "Image deleted successfully"}
    except HTTPException:
        raise
    except Error as e:
        conn.rollback()
        logger.error(f"Failed to delete image: {str(e)}")
        raise HTTPException(status_code=400, detail=f"Failed to delete image: {str(e)}")
    finally:
        cursor.close()
        conn.close()

# ==================== REGION & CATEGORY ENDPOINTS ====================

# 16. Get All Regions
@app.get("/regions")
def get_regions(language: Language = Language.ko):
    conn = get_db_connection()
    cursor = conn.cursor(dictionary=True)
    
    try:
        lang_column = f"region_name_{language.value}"
        query = f"""
        SELECT region_id, {lang_column} as region_name
        FROM board_regions
        ORDER BY region_id
        """
        cursor.execute(query)
        regions = cursor.fetchall()
        
        return {"regions": regions}
    except Error as e:
        logger.error(f"Failed to get regions: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Failed to retrieve regions: {str(e)}")
    finally:
        cursor.close()
        conn.close()

# 17. Get All Categories
@app.get("/categories")
def get_categories(language: Language = Language.ko):
    conn = get_db_connection()
    cursor = conn.cursor(dictionary=True)
    
    try:
        lang_column = f"name_{language.value}"
        query = f"""
        SELECT category_id, category_key, {lang_column} as category_name
        FROM board_categories
        ORDER BY category_id
        """
        cursor.execute(query)
        categories = cursor.fetchall()
        
        return {"categories": categories}
    except Error as e:
        logger.error(f"Failed to get categories: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Failed to retrieve categories: {str(e)}")
    finally:
        cursor.close()
        conn.close()

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)