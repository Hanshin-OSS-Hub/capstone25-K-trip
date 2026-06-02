-- Table to store user preferences for route recommendations
CREATE TABLE route_preferences (
    preference_id INT PRIMARY KEY AUTO_INCREMENT,
    user_id INT NOT NULL,
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    theme_id INT NOT NULL,
    schedule_type ENUM('relaxed', 'packed') NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE,
    FOREIGN KEY (theme_id) REFERENCES trip_themes(theme_id)
);

CREATE TABLE trip_themes (
    theme_id INT PRIMARY KEY AUTO_INCREMENT,
    theme_name VARCHAR(50) NOT NULL UNIQUE,
    theme_description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Table to store AI-generated route recommendations
CREATE TABLE recommended_routes (
    route_id INT PRIMARY KEY AUTO_INCREMENT,
    preference_id INT NOT NULL,
    route_name VARCHAR(200) NOT NULL,
    route_description TEXT,
    total_estimated_cost DECIMAL(10, 2),
    difficulty_level ENUM('easy', 'moderate', 'challenging'),
    generated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    is_active BOOLEAN DEFAULT TRUE,
    FOREIGN KEY (preference_id) REFERENCES route_preferences(preference_id) ON DELETE CASCADE
);

-- Table to store daily itinerary details for each recommended route
CREATE TABLE route_itinerary (
    itinerary_id INT PRIMARY KEY AUTO_INCREMENT,
    route_id INT NOT NULL,
    day_number INT NOT NULL,
    day_date DATE NOT NULL,
    day_description TEXT,
    FOREIGN KEY (route_id) REFERENCES recommended_routes(route_id) ON DELETE CASCADE,
    UNIQUE KEY unique_route_day (route_id, day_number),
    INDEX idx_itinerary_route_day (route_id, day_number)
);

-- Table to store individual activities within each day
CREATE TABLE itinerary_activities (
    activity_id INT PRIMARY KEY AUTO_INCREMENT,
    itinerary_id INT NOT NULL,
    activity_order INT NOT NULL,
    activity_time TIME,
    activity_name VARCHAR(200) NOT NULL,
    activity_description TEXT,
    location_name VARCHAR(200),
    location_address TEXT,
    coordinates POINT,
    estimated_duration_minutes INT DEFAULT NULL,
    estimated_cost DECIMAL(10, 2) DEFAULT NULL,
    activity_category_id INT,
    FOREIGN KEY (itinerary_id) REFERENCES route_itinerary(itinerary_id) ON DELETE CASCADE,
    FOREIGN KEY (activity_category_id) REFERENCES activity_categories(category_id),
    SPATIAL INDEX idx_activity_coordinates (coordinates)
);

CREATE TABLE activity_categories (
    category_id INT PRIMARY KEY AUTO_INCREMENT,
    category_name VARCHAR(50) NOT NULL UNIQUE,
    category_icon VARCHAR(50),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Table to track when users add recommended routes to their personal schedule
CREATE TABLE user_saved_routes (
    saved_route_id INT PRIMARY KEY AUTO_INCREMENT,
    user_id INT NOT NULL,
    route_id INT NOT NULL,
    saved_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    trip_status ENUM('planned', 'ongoing', 'completed', 'cancelled') DEFAULT 'planned',
    actual_start_date DATE,
    actual_end_date DATE,
    FOREIGN KEY (user_id) REFERENCES users(user_id),
    FOREIGN KEY (route_id) REFERENCES recommended_routes(route_id),
    UNIQUE KEY unique_user_route (user_id, route_id)
);

-- Table to store user ratings and feedback after trip completion
CREATE TABLE route_ratings (
    rating_id INT PRIMARY KEY AUTO_INCREMENT,
    saved_route_id INT NOT NULL,
    user_id INT NOT NULL,
    rating_type ENUM('thumbs_up', 'thumbs_down') NOT NULL,
    feedback_text VARCHAR(1000),
    rated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (saved_route_id) REFERENCES user_saved_routes(saved_route_id) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE,
    UNIQUE KEY unique_rating (saved_route_id, user_id)
);

-- Indexes for better query performance
CREATE INDEX idx_route_preferences_user ON route_preferences(user_id);
CREATE INDEX idx_route_preferences_dates ON route_preferences(start_date, end_date);
CREATE INDEX idx_recommended_routes_preference ON recommended_routes(preference_id);
CREATE INDEX idx_route_itinerary_route ON route_itinerary(route_id);
CREATE INDEX idx_itinerary_activities_itinerary ON itinerary_activities(itinerary_id);
CREATE INDEX idx_user_saved_routes_user ON user_saved_routes(user_id);
CREATE INDEX idx_user_saved_routes_status ON user_saved_routes(trip_status);
CREATE INDEX idx_route_ratings_saved_route ON route_ratings(saved_route_id);
CREATE INDEX idx_route_ratings_rating_type ON route_ratings(rating_type);
