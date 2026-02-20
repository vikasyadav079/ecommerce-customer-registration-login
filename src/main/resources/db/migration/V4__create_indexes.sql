-- V4: Indexes for identity and audit tables

-- Customer indexes
CREATE UNIQUE INDEX idx_customer_email_lower ON identity.customer (LOWER(email));
CREATE INDEX idx_customer_status ON identity.customer (status);
CREATE INDEX idx_customer_phone ON identity.customer (phone_number) WHERE phone_number IS NOT NULL;

-- Device indexes
CREATE INDEX idx_device_customer_id ON identity.device (customer_id, created_at);
CREATE INDEX idx_device_fingerprint ON identity.device (fingerprint);

-- MFA Secret indexes
CREATE INDEX idx_mfa_secret_customer_id ON identity.mfa_secret (customer_id);

-- Social Link indexes
CREATE INDEX idx_social_link_customer_id ON identity.social_link (customer_id);
CREATE INDEX idx_social_link_provider ON identity.social_link (provider, provider_id);

-- Password History indexes
CREATE INDEX idx_password_history_customer_id ON identity.password_history (customer_id, created_at DESC);

-- Consent indexes
CREATE INDEX idx_consent_customer_id ON identity.consent (customer_id, consent_type);

-- Audit Log indexes (on parent table — propagates to partitions)
CREATE INDEX idx_audit_log_customer_id ON audit.audit_log (customer_id, event_time);
CREATE INDEX idx_audit_log_event_type ON audit.audit_log (event_type, event_time);
CREATE INDEX idx_audit_log_resource ON audit.audit_log (resource_type, resource_id);
