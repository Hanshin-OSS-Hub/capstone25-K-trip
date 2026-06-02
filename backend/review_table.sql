-- Table to store specific locations that can be reviewed
CREATE TABLE locations (
    location_id INT PRIMARY KEY AUTO_INCREMENT,
    location_name VARCHAR(200) NOT NULL,
    location_address VARCHAR(300),
    city VARCHAR(100),
    country VARCHAR(100),
    coordinates POINT NOT NULL,
    location_category_id INT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    SPATIAL INDEX idx_coordinates (coordinates),
    INDEX idx_location_name (location_name),
    INDEX idx_location_city (city),
    FOREIGN KEY (location_category_id) REFERENCES location_categories(category_id)
);

CREATE TABLE location_categories (
    category_id INT PRIMARY KEY AUTO_INCREMENT,
    category_name VARCHAR(50) NOT NULL UNIQUE,
    category_description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Main review table
CREATE TABLE reviews (
    review_id INT PRIMARY KEY AUTO_INCREMENT,
    user_id INT NOT NULL,
    location_id INT NOT NULL,
    rating DECIMAL(2, 1) NOT NULL,
    review_comment TEXT,
    visit_date DATE,
    like_count INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    is_deleted BOOLEAN DEFAULT FALSE,
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE,
    FOREIGN KEY (location_id) REFERENCES locations(location_id) ON DELETE CASCADE,
    CONSTRAINT chk_rating CHECK (rating >= 1.0 AND rating <= 5.0 AND (rating * 2) = FLOOR(rating * 2)),
    INDEX idx_reviews_user (user_id),
    INDEX idx_reviews_location (location_id),
    INDEX idx_reviews_rating (rating),
    INDEX idx_reviews_active (is_deleted, created_at), 
    INDEX idx_reviews_likes (like_count DESC)
);

-- Table to store photos and videos associated with reviews
CREATE TABLE review_media (
    media_id INT PRIMARY KEY AUTO_INCREMENT,
    review_id INT NOT NULL,
    media_type ENUM('photo', 'video') NOT NULL,
    media_url VARCHAR(255) NOT NULL,
    media_thumbnail_url VARCHAR(255),
    file_size_bytes BIGINT,
    media_order INT DEFAULT 0,
    uploaded_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (review_id) REFERENCES reviews(review_id) ON DELETE CASCADE,
    INDEX idx_media_review (review_id),
    INDEX idx_media_type (media_type)
);

-- Table to store likes on reviews
CREATE TABLE review_likes (
    like_id INT PRIMARY KEY AUTO_INCREMENT,
    review_id INT NOT NULL,
    user_id INT NOT NULL,
    liked_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (review_id) REFERENCES reviews(review_id) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE,
    UNIQUE KEY unique_user_review_like (review_id, user_id),
    INDEX idx_review_likes_review (review_id),
    INDEX idx_review_likes_user (user_id)
);

-- View to get reviews with like counts
CREATE VIEW reviews_with_stats AS
SELECT 
    r.review_id,
    r.user_id,
    r.location_id,
    r.rating,
    r.review_title,
    r.review_comment,
    r.visit_date,
    r.created_at,
    r.updated_at,
    COUNT(DISTINCT rl.like_id) AS total_likes,
    COUNT(DISTINCT rm.media_id) AS total_media,
    COUNT(DISTINCT CASE WHEN rm.media_type = 'photo' THEN rm.media_id END) AS photo_count,
    COUNT(DISTINCT CASE WHEN rm.media_type = 'video' THEN rm.media_id END) AS video_count
FROM reviews r
LEFT JOIN review_likes rl ON r.review_id = rl.review_id
LEFT JOIN review_media rm ON r.review_id = rm.review_id
WHERE r.is_deleted = FALSE
GROUP BY r.review_id, r.user_id, r.location_id, r.rating, 
         r.review_title, r.review_comment, r.visit_date, 
         r.created_at, r.updated_at;
