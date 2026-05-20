-- k-trip 리워드 시스템 스키마

-- 레벨 테이블 (포인트에 따른 사용자 레벨 구간표)
CREATE TABLE reward_levels (
  level SMALLINT UNSIGNED PRIMARY KEY,
  min_points INT UNSIGNED NOT NULL,              
  title VARCHAR(50) NULL,                        
  benefits_json JSON NULL,                       -- 혜택(선택사항)
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uq_reward_levels_min_points (min_points)   --레벨 최소 포인트 같으면 안됨
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- 배지 테이블
CREATE TABLE badges (
  badge_id BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
  code VARCHAR(64) NOT NULL,           -- 레벨 외 추가 조건 달성 시 배지
  name VARCHAR(100) NOT NULL,
  description VARCHAR(300) NULL,       -- 배지 설명문
  icon_url VARCHAR(512) NULL,
  rule_json JSON NULL,                 -- 배지를 얻기 위한 규칙 (미션과 별개)
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uq_badges_code (code)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- 비콘: 현장 미션용
CREATE TABLE beacons (
  beacon_id BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
  code VARCHAR(64) NOT NULL,              -- UUID / 코드 저장
  uuid CHAR(36) NULL,
  major INT NULL,
  minor INT NULL,
  location_id BIGINT UNSIGNED NULL,       -- 특정 장소에 비콘 매핑
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uq_beacons_code (code),
  KEY idx_beacons_location (location_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- 행사: 특정 기간 참여 미션용
CREATE TABLE local_events (
  event_id BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
  title VARCHAR(200) NOT NULL,
  location_id BIGINT UNSIGNED NULL,
  starts_at DATETIME NULL,
  ends_at DATETIME NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  KEY idx_local_events_time (starts_at, ends_at),
  KEY idx_local_events_location (location_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- 미션 테이블
CREATE TABLE missions (
  mission_id BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
  code VARCHAR(64) NOT NULL,
  title VARCHAR(200) NOT NULL,
  mission_kind ENUM('APP','IRL') NOT NULL,
  category VARCHAR(50) NULL,                     -- 미션을 카테고리로 분류
  rule_json JSON NOT NULL,                       -- 달성 규칙
  points INT UNSIGNED NOT NULL DEFAULT 10,       -- 완료 시 지급 포인트
  trophy_icon_url VARCHAR(512) NULL,             -- "트로피" 표시용 아이콘
  reward_badge_id BIGINT UNSIGNED NULL,          -- 완료 시 즉시 주는 배지 (선택사항)
  active_from DATETIME NULL,
  active_to DATETIME NULL,
  max_times_per_user SMALLINT UNSIGNED NOT NULL DEFAULT 1,  
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uq_missions_code (code),
  KEY idx_missions_kind (mission_kind, category),
  KEY idx_missions_active (active_from, active_to)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- 사용자 리워드 이벤트 로그 테이블
CREATE TABLE user_reward_events (
  event_id BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
  user_id BIGINT UNSIGNED NOT NULL,
  action_code VARCHAR(50) NOT NULL,             
  related_id BIGINT UNSIGNED NULL,             
  meta_json JSON NULL,                           \
  occurred_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  KEY idx_user_reward_events_user_time (user_id, occurred_at),
  KEY idx_user_reward_events_action (action_code)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- 미션 별 진행도 및 완료 상태 테이블
CREATE TABLE user_mission_progress (
  user_id BIGINT UNSIGNED NOT NULL,
  mission_id BIGINT UNSIGNED NOT NULL,
  progress_count INT UNSIGNED NOT NULL DEFAULT 0,     
  status ENUM('IN_PROGRESS','PENDING_REVIEW','COMPLETED','REVOKED')
         NOT NULL DEFAULT 'IN_PROGRESS',             -- IRL 미션의 오프라인 검수 등 고려
  last_event_id BIGINT UNSIGNED NULL,
  completed_at DATETIME NULL,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (user_id, mission_id),
  KEY idx_ump_status (status),
  KEY idx_ump_completed (completed_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- 트로피 기록 테이블
CREATE TABLE user_trophies (
  user_id BIGINT UNSIGNED NOT NULL,
  mission_id BIGINT UNSIGNED NOT NULL,
  earned_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (user_id, mission_id),
  KEY idx_ut_earned (earned_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- 배지 획득 기록 테이블
CREATE TABLE user_badges (
  user_id BIGINT UNSIGNED NOT NULL,
  badge_id BIGINT UNSIGNED NOT NULL,
  earned_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (user_id, badge_id),
  KEY idx_ub_earned (earned_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- 포인트/레벨 요약(캐시) 테이블
CREATE TABLE user_reward_summary (
  user_id BIGINT UNSIGNED PRIMARY KEY,
  points INT UNSIGNED NOT NULL DEFAULT 0,
  level SMALLINT UNSIGNED NOT NULL DEFAULT 1,
  level_updated_at DATETIME NULL,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  KEY idx_urs_level (level),
  KEY idx_urs_points (points)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;



-- 추후 외래키 활성화

/*
 ALTER TABLE user_reward_events
   ADD CONSTRAINT fk_ure_user FOREIGN KEY (user_id) REFERENCES users(id);
*/

/*
 ALTER TABLE missions
   ADD CONSTRAINT fk_missions_reward_badge FOREIGN KEY (reward_badge_id) REFERENCES badges(badge_id);
*/

/*
 ALTER TABLE user_mission_progress
   ADD CONSTRAINT fk_ump_mission FOREIGN KEY (mission_id) REFERENCES missions(mission_id);
*/

/*
 ALTER TABLE user_trophies
   ADD CONSTRAINT fk_ut_mission FOREIGN KEY (mission_id) REFERENCES missions(mission_id);
*/

/*
 ALTER TABLE user_badges
   ADD CONSTRAINT fk_ub_badge FOREIGN KEY (badge_id) REFERENCES badges(badge_id);
*/