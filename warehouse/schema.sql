-- Analytics schema.
-- Same as source but without FKs, the assumption is that it is already handled upstream.
-- Idempotent: safe to run on every startup.

CREATE TABLE IF NOT EXISTS users (
    id uuid PRIMARY KEY, email text, name text, department text,
    country text, locale text, plan text, created_at timestamptz
);
CREATE TABLE IF NOT EXISTS models (
    id uuid PRIMARY KEY, name text, provider text,
    input_cost_per_1k numeric(10,5), output_cost_per_1k numeric(10,5)
);
CREATE TABLE IF NOT EXISTS assistants (
    id uuid PRIMARY KEY, name text, description text,
    system_prompt text, created_by uuid, created_at timestamptz
);
CREATE TABLE IF NOT EXISTS conversations (
    id uuid PRIMARY KEY, user_id uuid, assistant_id uuid,
    title text, source text, created_at timestamptz
);
CREATE TABLE IF NOT EXISTS messages (
    id uuid PRIMARY KEY, conversation_id uuid, user_id uuid, model_id uuid,
    role text, type text, content text, tool_payload jsonb, created_at timestamptz
);
CREATE TABLE IF NOT EXISTS usage (
    id uuid PRIMARY KEY, user_id uuid, model_id uuid,
    uncached_input_tokens integer, cached_input_tokens integer,
    output_tokens integer, created_at timestamptz
);
CREATE TABLE IF NOT EXISTS feedback (
    id uuid PRIMARY KEY, message_id uuid, user_id uuid,
    rating smallint, comment text, created_at timestamptz
);

-- Indexes for analytical join/aggregation patterns (not inherited via replication).
CREATE INDEX IF NOT EXISTS idx_wh_messages_conversation_id ON messages (conversation_id);
CREATE INDEX IF NOT EXISTS idx_wh_messages_created_at      ON messages (created_at);
CREATE INDEX IF NOT EXISTS idx_wh_conversations_assistant  ON conversations (assistant_id);
CREATE INDEX IF NOT EXISTS idx_wh_feedback_message_id      ON feedback (message_id);
CREATE INDEX IF NOT EXISTS idx_wh_usage_model_id           ON usage (model_id);
CREATE INDEX IF NOT EXISTS idx_wh_usage_user_id            ON usage (user_id);