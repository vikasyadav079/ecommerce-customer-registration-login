-- V2: Identity bounded context tables

-- Customer — core identity entity
CREATE TABLE identity.customer (
    id              UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
    email           VARCHAR(255)    NOT NULL,
    password_hash   VARCHAR(255),
    first_name      VARCHAR(100)    NOT NULL,
    last_name       VARCHAR(100)    NOT NULL,
    phone_number    VARCHAR(20),
    status          VARCHAR(20)     NOT NULL DEFAULT 'PENDING_VERIFICATION',
    email_verified  BOOLEAN         NOT NULL DEFAULT FALSE,
    phone_verified  BOOLEAN         NOT NULL DEFAULT FALSE,
    mfa_enabled     BOOLEAN         NOT NULL DEFAULT FALSE,
    failed_login_attempts INT       NOT NULL DEFAULT 0,
    locked_until    TIMESTAMP WITH TIME ZONE,
    last_login_at   TIMESTAMP WITH TIME ZONE,
    created_at      TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    version         BIGINT          NOT NULL DEFAULT 0
);

-- Device — trusted device registry
CREATE TABLE identity.device (
    id              UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_id     UUID            NOT NULL REFERENCES identity.customer(id),
    fingerprint     VARCHAR(255)    NOT NULL,
    device_name     VARCHAR(100),
    device_type     VARCHAR(20),
    os              VARCHAR(50),
    browser         VARCHAR(50),
    ip_address      VARCHAR(45),
    trusted         BOOLEAN         NOT NULL DEFAULT FALSE,
    last_used_at    TIMESTAMP WITH TIME ZONE,
    created_at      TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    version         BIGINT          NOT NULL DEFAULT 0
);

-- MFA Secret — TOTP secrets for multi-factor auth
CREATE TABLE identity.mfa_secret (
    id              UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_id     UUID            NOT NULL REFERENCES identity.customer(id),
    secret          VARCHAR(255)    NOT NULL,
    type            VARCHAR(20)     NOT NULL DEFAULT 'TOTP',
    verified        BOOLEAN         NOT NULL DEFAULT FALSE,
    created_at      TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    version         BIGINT          NOT NULL DEFAULT 0
);

-- Social Link — OAuth provider connections
CREATE TABLE identity.social_link (
    id              UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_id     UUID            NOT NULL REFERENCES identity.customer(id),
    provider        VARCHAR(20)     NOT NULL,
    provider_id     VARCHAR(255)    NOT NULL,
    provider_email  VARCHAR(255),
    linked_at       TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    created_at      TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    version         BIGINT          NOT NULL DEFAULT 0,
    UNIQUE (provider, provider_id)
);

-- Password History — prevent password reuse
CREATE TABLE identity.password_history (
    id              UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_id     UUID            NOT NULL REFERENCES identity.customer(id),
    password_hash   VARCHAR(255)    NOT NULL,
    created_at      TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

-- Consent — GDPR consent records
CREATE TABLE identity.consent (
    id              UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_id     UUID            NOT NULL REFERENCES identity.customer(id),
    consent_type    VARCHAR(50)     NOT NULL,
    granted         BOOLEAN         NOT NULL,
    ip_address      VARCHAR(45),
    user_agent      TEXT,
    granted_at      TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    revoked_at      TIMESTAMP WITH TIME ZONE,
    created_at      TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    version         BIGINT          NOT NULL DEFAULT 0
);
