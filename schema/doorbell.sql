-- Smart Doorbell Database Schema - SIMPLIFIED VERSION
-- Optimized for ESP32 doorbell with WebSocket streaming
--
-- DATABASE: doorbell

-- Terminate existing connections
SELECT pg_terminate_backend(pg_stat_activity.pid)
FROM pg_stat_activity
WHERE pg_stat_activity.datname = 'doorbell'
  AND pid <> pg_backend_pid();

SELECT 'CREATE DATABASE doorbell'
    WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'doorbell')\gexec

\c doorbell

ALTER DATABASE doorbell SET timezone TO 'Asia/Ho_Chi_Minh';
SELECT pg_reload_conf();

-- ============================================================================
-- ENUM TYPES (Simplified)
-- ============================================================================

CREATE TYPE event_type_enum AS ENUM (
    'DOORBELL_RING',
    'MOTION_DETECTED'
);

CREATE TYPE user_role_enum AS ENUM (
    'OWNER',
    'MEMBER'
);

CREATE TYPE granted_status_enum AS ENUM (
    'GRANTED',
    'REVOKED',
    'EXPIRED'
);

-- ============================================================================
-- USER TABLE
-- ============================================================================

CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    username VARCHAR(50) UNIQUE,
    email VARCHAR(255) NOT NULL UNIQUE,
    password VARCHAR(255) NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    is_email_verified BOOLEAN DEFAULT FALSE,
    last_login TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT username_format_chk CHECK (
        username IS NULL OR username ~ '^[A-Za-z0-9._-]{3,50}$'
    ),
    CONSTRAINT email_format_chk CHECK (
        email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'
    )
);

-- ============================================================================
-- DEVICES
-- ============================================================================

CREATE TABLE devices (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    device_id VARCHAR(100) UNIQUE NOT NULL,
    device_key VARCHAR(255) UNIQUE NOT NULL,
    name VARCHAR(255) NOT NULL,
    location VARCHAR(255),
    model VARCHAR(100),
    firmware_version VARCHAR(50),
    is_active BOOLEAN DEFAULT TRUE,
    battery_level INTEGER NOT NULL DEFAULT 100 CHECK (battery_level >= 0 AND battery_level <= 100),
    signal_strength INTEGER CHECK (signal_strength >= -100 AND signal_strength <= 0),
    chime_index INTEGER NOT NULL DEFAULT 1 CHECK (chime_index >= 1 AND chime_index <= 4),
    volume_level INTEGER NOT NULL DEFAULT 10 CHECK (volume_level >= 0 AND volume_level <= 100),
    night_mode_enabled BOOLEAN NOT NULL DEFAULT FALSE,
    night_mode_start TIMETZ,
    night_mode_end TIMETZ,
    last_online TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT night_mode_time_chk CHECK (
        (night_mode_start IS NULL AND night_mode_end IS NULL) OR
        (night_mode_start IS NOT NULL AND night_mode_end IS NOT NULL)
    )
);

-- ============================================================================
-- USER DEVICE ACCESS (RBAC)
-- ============================================================================

CREATE TABLE user_device_access (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    device_id UUID NOT NULL REFERENCES devices(id) ON DELETE CASCADE,
    role user_role_enum NOT NULL DEFAULT 'MEMBER',
    granted_status granted_status_enum NOT NULL DEFAULT 'GRANTED',
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_by UUID REFERENCES users(id) ON DELETE SET NULL
);

-- ============================================================================
-- EVENTS (Simplified: audit log for doorbell presses)
-- ============================================================================

CREATE TABLE events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    device_id UUID NOT NULL REFERENCES devices(id) ON DELETE CASCADE,
    event_timestamp TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    event_type event_type_enum NOT NULL DEFAULT 'DOORBELL_RING',
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================================
-- USER FCM TOKENS (Push Notifications)
-- ============================================================================

CREATE TABLE user_fcm_tokens (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    token TEXT NOT NULL,
    last_updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT unique_user_token UNIQUE (user_id, token)
);

-- ============================================================================
-- INDEXES
-- ============================================================================

CREATE INDEX idx_users_active ON users(is_active) WHERE is_active = TRUE;

CREATE INDEX idx_devices_active ON devices(is_active) WHERE is_active = TRUE;

CREATE INDEX idx_user_device_access_user ON user_device_access(user_id, role);
CREATE INDEX idx_user_device_access_device ON user_device_access(device_id, role);

CREATE INDEX idx_events_device_timestamp ON events(device_id, event_timestamp DESC);
CREATE INDEX idx_events_timestamp ON events(event_timestamp DESC);

CREATE INDEX idx_user_fcm_tokens_user ON user_fcm_tokens(user_id);

-- ============================================================================
-- EVENT IMAGES
-- ============================================================================

CREATE TABLE event_images (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    event_id UUID NOT NULL REFERENCES events(id) ON DELETE CASCADE,
    file_path TEXT NOT NULL,
    captured_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_event_images_event_id ON event_images(event_id);

-- ============================================================================
-- SAMPLE DATA
-- ============================================================================

-- INSERT INTO devices (device_id, name, location, model, firmware_version)
-- VALUES
--     ('DB001', 'Front Door', 'Main Entrance', 'SmartBell Pro', '2.4.1'),
--     ('DB002', 'Back Door', 'Garden Entry', 'SmartBell Lite', '2.3.8')
-- ON CONFLICT (device_id) DO NOTHING;

-- INSERT INTO users (username, email, password)
-- VALUES
--     ('thomas', 'thomas@example.com', 'admin_password')
-- ON CONFLICT (email) DO NOTHING;

-- UPDATE users
-- SET is_email_verified = TRUE
-- WHERE email = 'thomas@example.com';

-- INSERT INTO user_device_access (user_id, device_id, role, granted_status)
-- VALUES
--     ('thomas@example.com', 'DB001', 'OWNER', 'GRANTED'),
--     ('thomas@example.com', 'DB002', 'MEMBER', 'GRANTED');

