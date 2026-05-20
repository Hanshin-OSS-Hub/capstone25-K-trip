-- K-Trip 사용자/인증 스키마

SET NAMES utf8mb4;
SET time_zone = '+09:00';

DROP TABLE IF EXISTS verification_tokens;
DROP TABLE IF EXISTS sessions;
DROP TABLE IF EXISTS oauth_accounts;
DROP TABLE IF EXISTS users;

-- 사용자 테이블
CREATE TABLE users (
  id               BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  -- 로컬 가입/로그인을 위한 필드
  email            VARCHAR(320) NULL,
  password_hash    VARCHAR(100) NULL,  
  -- 공통 프로필
  name             VARCHAR(100) NULL,
  nickname         VARCHAR(50)  NULL,
  avatar_url       VARCHAR(512) NULL,

  is_guest         TINYINT(1) NOT NULL DEFAULT 0,          
  email_verified_at DATETIME NULL,

  created_at       DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at       DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

  PRIMARY KEY (id),
  UNIQUE KEY uq_users_email (email),                       
  KEY idx_users_created (created_at),
  KEY idx_users_is_guest (is_guest)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- ouath 계정 매핑 테이블
CREATE TABLE oauth_accounts (
  id                   BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  user_id              BIGINT UNSIGNED NOT NULL,
  provider             ENUM('google','apple') NOT NULL,
  provider_account_id  VARCHAR(191) NOT NULL,   
  email                VARCHAR(320) NULL,     
  access_token         TEXT NULL,
  refresh_token        TEXT NULL,
  token_expires_at     DATETIME NULL,

  created_at           DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at           DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

  PRIMARY KEY (id),
  CONSTRAINT fk_oa_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  UNIQUE KEY uq_provider_account (provider, provider_account_id), 
  KEY idx_oa_user (user_id),
  KEY idx_oa_provider_email (provider, email)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- 세션 테이블 (로컬/oauth/게스트)
CREATE TABLE sessions (
  id               BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  user_id          BIGINT UNSIGNED NULL,      
  session_token    CHAR(64) NOT NULL,         
  user_agent       VARCHAR(255) NULL,
  ip_address       VARBINARY(16) NULL,       
  expires_at       DATETIME NOT NULL,        
  revoked_at       DATETIME NULL,

  created_at       DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at       DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

  PRIMARY KEY (id),
  UNIQUE KEY uq_sessions_token (session_token),
  KEY idx_sessions_user (user_id),
  KEY idx_sessions_expires (expires_at),
  CONSTRAINT fk_sessions_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- 검증/복구 토큰 테이블
CREATE TABLE verification_tokens (
  id           BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  user_id      BIGINT UNSIGNED NOT NULL,
  token_type   ENUM('email_verify','password_reset') NOT NULL,
  token        CHAR(64) NOT NULL,      
  expires_at   DATETIME NOT NULL,
  used_at      DATETIME NULL,

  created_at   DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

  PRIMARY KEY (id),
  UNIQUE KEY uq_verif_token (token_type, token),
  KEY idx_verif_user (user_id),
  KEY idx_verif_expires (expires_at),
  CONSTRAINT fk_verif_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

