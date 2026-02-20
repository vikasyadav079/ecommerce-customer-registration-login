-- V1: Create schemas for bounded contexts
-- Each bounded context owns its own schema for data isolation

CREATE SCHEMA IF NOT EXISTS identity;
CREATE SCHEMA IF NOT EXISTS audit;
