-- Sunliao backend schema v1
-- Target: PostgreSQL 15+

CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- users
CREATE TABLE IF NOT EXISTS users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  uid VARCHAR(20) NOT NULL UNIQUE,
  phone VARCHAR(20) NOT NULL UNIQUE,
  nickname VARCHAR(32) NOT NULL DEFAULT '神秘人',
  avatar_url TEXT,
  signature VARCHAR(120) NOT NULL DEFAULT '这个人很神秘，什么都没留下',
  status VARCHAR(64) NOT NULL DEFAULT '想找人聊聊',
  is_online BOOLEAN NOT NULL DEFAULT FALSE,
  last_online_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_users_uid ON users(uid);
CREATE INDEX IF NOT EXISTS idx_users_phone ON users(phone);

-- auth session
CREATE TABLE IF NOT EXISTS auth_sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  device_id VARCHAR(128) NOT NULL,
  refresh_token_hash VARCHAR(128) NOT NULL,
  ip VARCHAR(64),
  user_agent TEXT,
  expires_at TIMESTAMPTZ NOT NULL,
  revoked_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(user_id, device_id)
);

CREATE INDEX IF NOT EXISTS idx_auth_sessions_user ON auth_sessions(user_id);

-- user settings
CREATE TABLE IF NOT EXISTS user_settings (
  user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  invisible_mode BOOLEAN NOT NULL DEFAULT FALSE,
  notification_enabled BOOLEAN NOT NULL DEFAULT TRUE,
  vibration_enabled BOOLEAN NOT NULL DEFAULT TRUE,
  day_theme_enabled BOOLEAN NOT NULL DEFAULT FALSE,
  transparent_homepage BOOLEAN NOT NULL DEFAULT FALSE,
  portrait_fullscreen_background BOOLEAN NOT NULL DEFAULT FALSE,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- block relation
CREATE TABLE IF NOT EXISTS user_blocks (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  blocker_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  blocked_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(blocker_id, blocked_id),
  CHECK (blocker_id <> blocked_id)
);

CREATE INDEX IF NOT EXISTS idx_user_blocks_blocker ON user_blocks(blocker_id);
CREATE INDEX IF NOT EXISTS idx_user_blocks_blocked ON user_blocks(blocked_id);

-- friend request
CREATE TABLE IF NOT EXISTS friend_requests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  from_user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  to_user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  message VARCHAR(120),
  status VARCHAR(16) NOT NULL DEFAULT 'pending',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CHECK (status IN ('pending', 'accepted', 'rejected')),
  CHECK (from_user_id <> to_user_id)
);

CREATE INDEX IF NOT EXISTS idx_friend_requests_to ON friend_requests(to_user_id, status);

-- friendship (mutual)
CREATE TABLE IF NOT EXISTS friendships (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_a UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  user_b UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  is_mutual_follow BOOLEAN NOT NULL DEFAULT FALSE,
  is_unfollowed BOOLEAN NOT NULL DEFAULT FALSE,
  messages_since_unfollow INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CHECK (user_a <> user_b)
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_friendships_pair
ON friendships (LEAST(user_a, user_b), GREATEST(user_a, user_b));

-- match sessions
CREATE TABLE IF NOT EXISTS match_sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  matched_user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  status VARCHAR(16) NOT NULL DEFAULT 'matched',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  expires_at TIMESTAMPTZ NOT NULL,
  CHECK (status IN ('queued', 'matched', 'cancelled', 'expired')),
  CHECK (user_id <> matched_user_id)
);

CREATE INDEX IF NOT EXISTS idx_match_sessions_user ON match_sessions(user_id, created_at DESC);

-- threads
CREATE TABLE IF NOT EXISTS chat_threads (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_a UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  user_b UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  is_friend BOOLEAN NOT NULL DEFAULT FALSE,
  is_deleted_by_a BOOLEAN NOT NULL DEFAULT FALSE,
  is_deleted_by_b BOOLEAN NOT NULL DEFAULT FALSE,
  expires_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CHECK (user_a <> user_b)
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_chat_threads_pair
ON chat_threads (LEAST(user_a, user_b), GREATEST(user_a, user_b));

-- thread state (per user)
CREATE TABLE IF NOT EXISTS chat_thread_states (
  thread_id UUID NOT NULL REFERENCES chat_threads(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  unread_count INTEGER NOT NULL DEFAULT 0,
  last_read_message_id UUID,
  last_read_at TIMESTAMPTZ,
  PRIMARY KEY (thread_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_thread_states_user ON chat_thread_states(user_id);

-- messages
CREATE TABLE IF NOT EXISTS chat_messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  thread_id UUID NOT NULL REFERENCES chat_threads(id) ON DELETE CASCADE,
  sender_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  message_type VARCHAR(16) NOT NULL DEFAULT 'text',
  content TEXT,
  image_url TEXT,
  image_quality VARCHAR(16),
  is_burn_after_reading BOOLEAN NOT NULL DEFAULT FALSE,
  burn_seconds INTEGER,
  burned_at TIMESTAMPTZ,
  status VARCHAR(16) NOT NULL DEFAULT 'sent',
  client_msg_id VARCHAR(64),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CHECK (message_type IN ('text', 'image', 'system')),
  CHECK (status IN ('sending', 'sent', 'failed', 'recalled')),
  CHECK (
    (message_type = 'text' AND content IS NOT NULL)
    OR (message_type = 'image' AND image_url IS NOT NULL)
    OR (message_type = 'system')
  )
);

CREATE INDEX IF NOT EXISTS idx_chat_messages_thread ON chat_messages(thread_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_chat_messages_sender ON chat_messages(sender_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_chat_messages_client_msg_id ON chat_messages(client_msg_id);

-- message read status (peer-read semantics)
CREATE TABLE IF NOT EXISTS message_reads (
  message_id UUID NOT NULL REFERENCES chat_messages(id) ON DELETE CASCADE,
  reader_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  read_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (message_id, reader_id)
);

-- intimacy state
CREATE TABLE IF NOT EXISTS intimacy_states (
  thread_id UUID PRIMARY KEY REFERENCES chat_threads(id) ON DELETE CASCADE,
  points INTEGER NOT NULL DEFAULT 0,
  total_chat_minutes INTEGER NOT NULL DEFAULT 0,
  stage1_unlocked_at TIMESTAMPTZ,
  stage2_unlocked_at TIMESTAMPTZ,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- feature policy config
CREATE TABLE IF NOT EXISTS feature_policy_configs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  policy_key VARCHAR(64) NOT NULL UNIQUE,
  policy_value JSONB NOT NULL,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- audit log
CREATE TABLE IF NOT EXISTS audit_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  actor_user_id UUID REFERENCES users(id) ON DELETE SET NULL,
  action VARCHAR(64) NOT NULL,
  target_type VARCHAR(32),
  target_id VARCHAR(64),
  metadata JSONB,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_audit_logs_actor ON audit_logs(actor_user_id, created_at DESC);

