-- =============================================================================
-- EndpointSecurityML - PostgreSQL schema
-- Executed automatically on first start of the postgres container
-- (mounted at /docker-entrypoint-initdb.d)
-- =============================================================================

-- The compose file only creates the "airflow" database by default, so create
-- the application database here if it is missing.
SELECT 'CREATE DATABASE endpointsecurity'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'endpointsecurity')\gexec

\connect endpointsecurity

-- =============================================================================
-- Tables
-- =============================================================================
CREATE TABLE IF NOT EXISTS endpoint_activities (
    activity_id          SERIAL PRIMARY KEY,
    timestamp            TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    computer_name        VARCHAR(100),
    username             VARCHAR(100),
    process_name         VARCHAR(255),
    parent_process       VARCHAR(255),
    network_connections  INTEGER DEFAULT 0,
    is_attack            BOOLEAN DEFAULT FALSE,
    threat_type          VARCHAR(50)
);

CREATE TABLE IF NOT EXISTS threat_detections (
    detection_id          SERIAL PRIMARY KEY,
    activity_id           INTEGER REFERENCES endpoint_activities(activity_id),
    detected_at           TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    predicted_threat_type VARCHAR(50),
    confidence_score      DOUBLE PRECISION,
    model_version         VARCHAR(50)
);

CREATE INDEX IF NOT EXISTS idx_activities_is_attack ON endpoint_activities (is_attack);
CREATE INDEX IF NOT EXISTS idx_activities_timestamp ON endpoint_activities (timestamp);
CREATE INDEX IF NOT EXISTS idx_detections_activity  ON threat_detections (activity_id);

-- =============================================================================
-- Seed data - only inserted into an empty table so re-runs are idempotent
-- =============================================================================
DO $$
BEGIN
    IF (SELECT COUNT(*) FROM endpoint_activities) = 0 THEN

        -- 800 benign activities: low connection counts, legitimate processes
        INSERT INTO endpoint_activities
            (timestamp, computer_name, username, process_name,
             parent_process, network_connections, is_attack, threat_type)
        SELECT
            NOW() - (INTERVAL '90 days' * random()),
            'COMPUTER' || FLOOR(random() * 10)::int,
            CASE WHEN random() < 0.15 THEN 'system' ELSE 'user' END,
            (ARRAY['explorer.exe','svchost.exe','chrome.exe',
                   'outlook.exe','notepad.exe','Teams.exe','OneDrive.exe'])
                [1 + FLOOR(random() * 7)::int],
            (ARRAY['winlogon.exe','services.exe','explorer.exe','userinit.exe'])
                [1 + FLOOR(random() * 4)::int],
            FLOOR(random() * 6)::int,
            FALSE,
            NULL
        FROM generate_series(1, 800);

        -- 200 malicious activities: attack tooling + high fan-out
        INSERT INTO endpoint_activities
            (timestamp, computer_name, username, process_name,
             parent_process, network_connections, is_attack, threat_type)
        SELECT
            NOW() - (INTERVAL '90 days' * random()),
            'COMPUTER' || FLOOR(random() * 10)::int,
            CASE WHEN random() < 0.35 THEN 'system' ELSE 'attacker' END,
            (ARRAY['powershell.exe','cmd.exe','wannacry.exe','mimikatz.exe'])
                [1 + FLOOR(random() * 4)::int],
            (ARRAY['services.exe','winlogon.exe','explorer.exe'])
                [1 + FLOOR(random() * 3)::int],
            (10 + FLOOR(random() * 30))::int,
            TRUE,
            CASE WHEN random() < 0.5 THEN 'Ransomware' ELSE 'Malware' END
        FROM generate_series(1, 200);

        RAISE NOTICE 'Seed data inserted: 800 normal + 200 attack activities';
    ELSE
        RAISE NOTICE 'endpoint_activities already populated - skipping seed';
    END IF;
END
$$;

-- =============================================================================
-- Summary
-- =============================================================================
SELECT
    COUNT(*)                                    AS total_records,
    COUNT(*) FILTER (WHERE is_attack)           AS attacks,
    COUNT(*) FILTER (WHERE NOT is_attack)       AS normal
FROM endpoint_activities;
