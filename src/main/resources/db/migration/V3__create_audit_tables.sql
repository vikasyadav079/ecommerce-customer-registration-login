-- V3: Audit bounded context tables

-- Audit Log — partitioned by event_time for efficient querying
CREATE TABLE audit.audit_log (
    id              UUID            NOT NULL DEFAULT gen_random_uuid(),
    event_type      VARCHAR(50)     NOT NULL,
    event_time      TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    customer_id     UUID,
    actor_id        VARCHAR(255),
    actor_type      VARCHAR(20)     NOT NULL DEFAULT 'CUSTOMER',
    resource_type   VARCHAR(50),
    resource_id     VARCHAR(255),
    action          VARCHAR(50)     NOT NULL,
    result          VARCHAR(20)     NOT NULL DEFAULT 'SUCCESS',
    ip_address      VARCHAR(45),
    user_agent      TEXT,
    metadata        JSONB,
    created_at      TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    PRIMARY KEY (id, event_time)
) PARTITION BY RANGE (event_time);

-- Initial monthly partitions
CREATE TABLE audit.audit_log_2025_01 PARTITION OF audit.audit_log
    FOR VALUES FROM ('2025-01-01') TO ('2025-02-01');
CREATE TABLE audit.audit_log_2025_02 PARTITION OF audit.audit_log
    FOR VALUES FROM ('2025-02-01') TO ('2025-03-01');
CREATE TABLE audit.audit_log_2025_03 PARTITION OF audit.audit_log
    FOR VALUES FROM ('2025-03-01') TO ('2025-04-01');
CREATE TABLE audit.audit_log_2025_04 PARTITION OF audit.audit_log
    FOR VALUES FROM ('2025-04-01') TO ('2025-05-01');
CREATE TABLE audit.audit_log_2025_05 PARTITION OF audit.audit_log
    FOR VALUES FROM ('2025-05-01') TO ('2025-06-01');
CREATE TABLE audit.audit_log_2025_06 PARTITION OF audit.audit_log
    FOR VALUES FROM ('2025-06-01') TO ('2025-07-01');
CREATE TABLE audit.audit_log_2025_07 PARTITION OF audit.audit_log
    FOR VALUES FROM ('2025-07-01') TO ('2025-08-01');
CREATE TABLE audit.audit_log_2025_08 PARTITION OF audit.audit_log
    FOR VALUES FROM ('2025-08-01') TO ('2025-09-01');
CREATE TABLE audit.audit_log_2025_09 PARTITION OF audit.audit_log
    FOR VALUES FROM ('2025-09-01') TO ('2025-10-01');
CREATE TABLE audit.audit_log_2025_10 PARTITION OF audit.audit_log
    FOR VALUES FROM ('2025-10-01') TO ('2025-11-01');
CREATE TABLE audit.audit_log_2025_11 PARTITION OF audit.audit_log
    FOR VALUES FROM ('2025-11-01') TO ('2025-12-01');
CREATE TABLE audit.audit_log_2025_12 PARTITION OF audit.audit_log
    FOR VALUES FROM ('2025-12-01') TO ('2026-01-01');
CREATE TABLE audit.audit_log_2026_01 PARTITION OF audit.audit_log
    FOR VALUES FROM ('2026-01-01') TO ('2026-02-01');
CREATE TABLE audit.audit_log_2026_02 PARTITION OF audit.audit_log
    FOR VALUES FROM ('2026-02-01') TO ('2026-03-01');
CREATE TABLE audit.audit_log_2026_03 PARTITION OF audit.audit_log
    FOR VALUES FROM ('2026-03-01') TO ('2026-04-01');
