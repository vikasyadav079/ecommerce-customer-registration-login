# Technical Foundation Setup Guide

## ECommerce CIAM Platform — Architecture Foundation

This guide documents the complete technical foundation for the ECommerce Customer Identity and Access Management (CIAM) platform. It covers all 20 foundation steps required before any business logic can be implemented.

**Stack**: Spring Boot 3.4.2 / Java 21 / PostgreSQL 16 / Redis 7 / Kafka 3.x / AWS EKS

---

## Table of Contents

1. [Maven Dependencies & Build Configuration](#step-1-maven-dependencies--build-configuration)
2. [Modular Monolith Package Structure](#step-2-modular-monolith-package-structure)
3. [Application Configuration (YAML)](#step-3-application-configuration-yaml)
4. [Database Foundation (Flyway Migrations)](#step-4-database-foundation-flyway-migrations)
5. [Spring Security Foundation](#step-5-spring-security-foundation)
6. [Redis Foundation](#step-6-redis-foundation)
7. [Kafka Foundation](#step-7-kafka-foundation)
8. [Shared Kernel & Cross-Cutting Concerns](#step-8-shared-kernel--cross-cutting-concerns)
9. [Observability Foundation](#step-9-observability-foundation)
10. [Resilience Foundation](#step-10-resilience-foundation)
11. [API Documentation (SpringDoc OpenAPI)](#step-11-api-documentation-springdoc-openapi)
12. [Docker Foundation](#step-12-docker-foundation)
13. [Testing Foundation](#step-13-testing-foundation)
14. [Application Verification Checklist](#step-14-application-verification-checklist)
15. [Terraform IaC — AWS Infrastructure](#step-15-terraform-iac--aws-infrastructure)
16. [Kubernetes Manifests & Helm Charts](#step-16-kubernetes-manifests--helm-charts)
17. [CI/CD Pipeline (GitHub Actions + ArgoCD)](#step-17-cicd-pipeline-github-actions--argocd)
18. [Performance Testing Foundation (Gatling)](#step-18-performance-testing-foundation-gatling)
19. [Monitoring & Alerting (Prometheus + Grafana)](#step-19-monitoring--alerting-prometheus--grafana)
20. [Full Verification & Runbook](#step-20-full-verification--runbook)

---

## Step 1: Maven Dependencies & Build Configuration

**File**: `pom.xml`

### Dependencies by Concern

| Concern | Dependencies |
|---------|-------------|
| **Web** | `spring-boot-starter-web`, `spring-boot-starter-validation` |
| **Security** | `spring-boot-starter-security`, `spring-boot-starter-oauth2-resource-server`, `spring-security-oauth2-authorization-server` (1.4.1) |
| **Data** | `spring-boot-starter-data-jpa`, `postgresql`, `flyway-core`, `flyway-database-postgresql` |
| **Redis** | `spring-boot-starter-data-redis` |
| **Messaging** | `spring-kafka` |
| **Resilience** | `resilience4j-spring-boot3` (2.2.0), `bucket4j_jdk17-core` (8.10.1) |
| **Observability** | `spring-boot-starter-actuator`, `micrometer-registry-prometheus`, `logstash-logback-encoder` (8.0) |
| **API Docs** | `springdoc-openapi-starter-webmvc-ui` (2.8.4) |
| **Mapping** | `mapstruct` (1.6.3) |
| **MFA** | `totp` (1.7.1) |
| **Utilities** | `libphonenumber` (8.13.27) |
| **Test** | `spring-boot-starter-test`, `spring-security-test`, `spring-kafka-test`, `h2`, Testcontainers (1.20.4) BOM, `archunit-junit5` (1.3.0) |

### Build Plugins

- **maven-compiler-plugin**: Java 21, MapStruct annotation processor with `defaultComponentModel=spring`
- **flyway-maven-plugin**: Multi-schema support (public, identity, audit)
- **maven-failsafe-plugin**: Integration test execution
- **spring-boot-maven-plugin**: Layered JAR configuration for optimized Docker images

---

## Step 2: Modular Monolith Package Structure

```
org.example
├── shared/                          # Cross-cutting concerns (shared kernel)
│   ├── config/                      # Spring configuration classes
│   ├── domain/                      # Value objects (CustomerId, DeviceInfo)
│   ├── event/                       # Domain event infrastructure
│   ├── exception/                   # Error codes, business exceptions, global handler
│   ├── dto/                         # API response envelope, error DTOs
│   ├── security/                    # Spring Security, JWT, CORS, password encoding
│   ├── persistence/                 # Auditable base entity
│   └── util/                        # Utilities
├── identity/                        # Authentication & identity bounded context
│   ├── controller/
│   ├── service/
│   ├── repository/
│   ├── domain/entity/
│   ├── domain/valueobject/
│   ├── dto/
│   ├── mapper/
│   └── event/
├── profile/                         # Customer profile bounded context
├── notification/                    # Notification bounded context
└── audit/                           # Audit logging bounded context
```

### Dependency Rules (enforced by ArchUnit)

- **Bounded contexts** (identity, profile, notification, audit) must NOT depend on each other
- **Shared** must NOT depend on any bounded context
- **Controllers** must NOT access repositories directly
- Cross-context communication is via **domain events** (Kafka)

Each package contains a `package-info.java` documenting its purpose and allowed dependencies.

---

## Step 3: Application Configuration (YAML)

**Deleted**: `application.properties`, `application-test.properties`
**Created**: `application.yml`, `application-dev.yml`, `application-test.yml`, `application-staging.yml`, `application-prod.yml`

### Key Configuration

| Setting | Value | Notes |
|---------|-------|-------|
| `spring.threads.virtual.enabled` | `true` | Project Loom virtual threads |
| `spring.jpa.open-in-view` | `false` | Prevents lazy loading in controllers |
| `hibernate.ddl-auto` | `validate` (dev) / `none` (prod) | Flyway manages schema |
| `spring.flyway.schemas` | `public,identity,audit` | Multi-schema support |
| Jackson | ISO dates, non-null, UTC | Consistent API output |
| Server | Graceful shutdown, compression | Production-ready defaults |
| Actuator | health, prometheus, metrics, info | Monitoring endpoints |

### Profile Summary

| Profile | Use | DB | Redis | Logging |
|---------|-----|-----|-------|---------|
| `dev` | Local development | PostgreSQL localhost | Standalone | DEBUG, console |
| `test` | Unit tests | H2 in-memory | N/A | WARN |
| `staging` | Staging env | Aurora | Cluster | INFO, JSON |
| `prod` | Production | Aurora Global | 16-shard cluster | INFO, JSON |

---

## Step 4: Database Foundation (Flyway Migrations)

**Location**: `src/main/resources/db/migration/`

| Migration | Description |
|-----------|-------------|
| `V1__create_schemas.sql` | Creates `identity` and `audit` schemas |
| `V2__create_identity_tables.sql` | `customer`, `device`, `mfa_secret`, `social_link`, `password_history`, `consent` |
| `V3__create_audit_tables.sql` | `audit.audit_log` with `PARTITION BY RANGE (event_time)`, monthly partitions |
| `V4__create_indexes.sql` | Unique `LOWER(email)`, composite indexes, covering indexes |

### Table Design Conventions

- UUID primary keys (database-generated via `gen_random_uuid()`)
- `created_at` / `updated_at` timestamps with timezone
- `version` column for optimistic locking
- All tables in schema-qualified form (`identity.customer`, `audit.audit_log`)

### Migration Conventions

- **Naming**: `V{version}__{description}.sql` (double underscore)
- **Pattern**: Expand-contract for zero-downtime migrations
- **Production**: `flyway.clean-disabled: true`

---

## Step 5: Spring Security Foundation

### Files

| File | Purpose |
|------|---------|
| `SecurityConfig.java` | Filter chain, public endpoints, JWT resource server, stateless sessions, security headers |
| `PasswordEncoderConfig.java` | BCrypt with strength 12 |
| `JwtConfig.java` | NimbusJwtDecoder with RSA public key |
| `CorsConfig.java` | Origin-based CORS (dev: localhost, prod: *.ecommerce.com) |

### Public Endpoints (No Auth Required)

- `/api/v1/auth/register`, `/api/v1/auth/login`, `/api/v1/auth/verify-email`
- `/api/v1/auth/forgot-password`, `/api/v1/auth/reset-password`, `/api/v1/auth/refresh-token`
- `/api/v1/auth/otp/**`
- `/actuator/health/**`, `/actuator/prometheus`, `/actuator/info`
- `/swagger-ui/**`, `/v3/api-docs/**`

### Security Headers

- `Content-Security-Policy: default-src 'self'; frame-ancestors 'none'`
- `X-Frame-Options: DENY`
- `X-Content-Type-Options: nosniff`
- `Referrer-Policy: strict-origin-when-cross-origin`

### Dev RSA Keys

Located at `src/main/resources/keys/dev-private.pem` and `dev-public.pem`. See `keys/README.md` for regeneration commands.

---

## Step 6: Redis Foundation

**File**: `shared/config/RedisConfig.java`

### Configuration

- `RedisTemplate<String, Object>` with Jackson JSON serialization (JavaTimeModule for dates)
- `StringRedisTemplate` for simple counters and rate limiters
- Connection pooling via Lettuce (standalone for dev, cluster for prod)

### Key Namespace Convention

| Pattern | Use |
|---------|-----|
| `ecommerce:session:{id}` | User sessions |
| `ecommerce:ratelimit:{type}:{key}` | Rate limit counters |
| `ecommerce:otp:{customerId}` | OTP codes |
| `ecommerce:token:blacklist:{jti}` | Revoked JWT tokens |

---

## Step 7: Kafka Foundation

### Topics

| Topic | Partitions | Description |
|-------|-----------|-------------|
| `auth.login.events` | 12 | Login success/failure events |
| `auth.registration.events` | 6 | New registrations |
| `auth.password.events` | 6 | Password changes/resets |
| `auth.session.events` | 12 | Session create/destroy/refresh |
| `auth.security.events` | 6 | Lockouts, suspicious activity |
| `auth.audit.events` | 12 | Audit trail events |
| `notifications.email` | 6 | Email dispatch |
| `notifications.sms` | 6 | SMS dispatch |

### Error Handling

- `DefaultErrorHandler` with `FixedBackOff(1000L, 3)` — retry 3 times, 1s apart
- `DeadLetterPublishingRecoverer` routes failed messages to `{topic}.DLT`

### Domain Event Infrastructure

- `DomainEvent` — Abstract base with eventId, eventType, occurredAt, customerId, metadata
- `DomainEventPublisher` — Interface for topic-based publishing
- `KafkaDomainEventPublisher` — Implementation using KafkaTemplate with async callbacks

---

## Step 8: Shared Kernel & Cross-Cutting Concerns

### Domain Primitives

| Class | Type | Description |
|-------|------|-------------|
| `CustomerId` | Record | UUID value object with factory methods |
| `DeviceInfo` | Record | fingerprint, name, type, os, browser, ip, userAgent |

### Persistence

- `AbstractAuditableEntity` — `@MappedSuperclass` with UUID id, `@CreatedDate`, `@LastModifiedDate`, `@Version`
- `JpaAuditingConfig` — `@EnableJpaAuditing`

### API Response Envelope

```java
ApiResponse<T> { success, data, error, requestId, timestamp }
ErrorResponse { code, message, details }
ValidationError { field, message, rejectedValue }
```

### Error Codes

| Code | HTTP | Description |
|------|------|-------------|
| AUTH-001 | 401 | Invalid credentials |
| AUTH-002 | 423 | Account locked |
| AUTH-003 | 403 | Account not verified |
| AUTH-004 | 401 | Token expired |
| AUTH-005 | 401 | Invalid token |
| AUTH-006 | 403 | MFA required |
| REG-001 | 409 | Email already registered |
| REG-002 | 409 | Phone already registered |
| REG-003 | 400 | Registration validation failed |
| RATE-001 | 429 | Rate limit exceeded |
| PWD-001 | 400 | Password policy violation |
| PWD-002 | 400 | Password recently used |
| GEN-001 | 404 | Resource not found |
| GEN-002 | 400 | Validation failed |
| GEN-999 | 500 | Internal server error |

### Global Exception Handler

`@RestControllerAdvice` handling:
- `BusinessException` → mapped ErrorCode HTTP status
- `MethodArgumentNotValidException` → 400 with field-level details
- `AccessDeniedException` → 403
- `Exception` (catch-all) → 500

---

## Step 9: Observability Foundation

### Metrics

- `ObservabilityConfig` — Common Micrometer tags (`application`, `environment`)
- Prometheus endpoint at `/actuator/prometheus`

### Request Tracing

- `MdcFilter` (`OncePerRequestFilter`, highest precedence)
  - Extracts/generates `X-Request-ID` header
  - Sets `requestId`, `customerId` in MDC
  - Returns `X-Request-ID` in response headers

### Structured Logging

`logback-spring.xml` profiles:
- **dev/default**: Human-readable with `[requestId]` pattern
- **staging/prod**: `LogstashEncoder` JSON with MDC fields
- **test**: Minimal WARN level

---

## Step 10: Resilience Foundation

### Circuit Breakers (Resilience4j)

| Instance | Failure Rate | Wait Duration | Use Case |
|----------|-------------|---------------|----------|
| `riskEngine` | 50% | 15s | Risk assessment service |
| `socialAuth` | 60% | 10s | OAuth providers |
| `externalApi` | 50% | 10s | Generic external APIs |

### Retries

| Instance | Max Attempts | Backoff | Use Case |
|----------|-------------|---------|----------|
| `kafkaProducer` | 5 | Exponential ×2 | Kafka publish failures |
| `externalApi` | 3 | Exponential ×2 | External API calls |

### Bulkheads

| Instance | Max Concurrent | Use Case |
|----------|---------------|----------|
| `googleOAuth` | 50 | Google OAuth calls |
| `facebookOAuth` | 50 | Facebook OAuth calls |

### Fallback Pattern Template

```java
@CircuitBreaker(name = "externalApi", fallbackMethod = "fallback")
@Retry(name = "externalApi")
public Result callExternalService() { ... }

public Result fallback(Exception ex) {
    log.warn("Fallback triggered: {}", ex.getMessage());
    return Result.defaultValue();
}
```

---

## Step 11: API Documentation (SpringDoc OpenAPI)

**File**: `shared/config/OpenApiConfig.java`

### Configuration

- Bearer JWT security scheme
- API Groups: `identity`, `profile`, `audit`, `actuator`
- Swagger UI at `/swagger-ui.html`
- OpenAPI spec at `/v3/api-docs`

### API Groups

| Group | Paths |
|-------|-------|
| identity | `/api/v1/auth/**`, `/api/v1/sessions/**`, `/api/v1/mfa/**`, `/api/v1/devices/**` |
| profile | `/api/v1/profile/**` |
| audit | `/api/v1/audit/**` |
| actuator | `/actuator/**` |

---

## Step 12: Docker Foundation

### Dockerfile (Multi-stage)

1. **Build stage**: `eclipse-temurin:21-jdk` + Maven
2. **Extract stage**: Layer extraction for cache optimization
3. **Runtime stage**: `eclipse-temurin:21-jre`, non-root user, ZGC, health check

### docker-compose.yml (Local Development)

| Service | Image | Port |
|---------|-------|------|
| PostgreSQL | `postgres:16-alpine` | 5432 |
| Redis | `redis:7-alpine` | 6379 |
| Kafka | `apache/kafka:3.8.0` (KRaft, no ZooKeeper) | 9092 |
| OpenSearch | `opensearchproject/opensearch:2.17.1` | 9200 |

All services have health checks and named volumes.

### Quick Start

```bash
docker-compose up -d
mvn spring-boot:run -Dspring-boot.run.profiles=dev
```

---

## Step 13: Testing Foundation

### ArchUnit Tests

| Test | Rules |
|------|-------|
| `PackageBoundaryTest` | Context isolation, shared independence, controller-repository separation, no cycles |
| `CodingConventionTest` | `@RestController` in controller pkg, `@Service` in service pkg, `@Entity` in entity pkg, repositories are interfaces |

### Integration Test Base

`BaseIntegrationTest` — Abstract class with `@SpringBootTest` + `@Testcontainers`:
- PostgreSQL 16 container
- Kafka container
- `@DynamicPropertySource` for test configuration

### Test Configuration

`src/test/resources/application-test.yml`:
- H2 in PostgreSQL mode (unit tests)
- Flyway disabled
- Session store: none

---

## Step 14: Application Verification Checklist

| # | Check | Command | Expected |
|---|-------|---------|----------|
| 1 | Dependencies | `mvn dependency:resolve` | BUILD SUCCESS |
| 2 | Compilation | `mvn compile` | BUILD SUCCESS |
| 3 | Docker infra | `docker-compose up -d` | 4 containers healthy |
| 4 | App starts | `mvn spring-boot:run -Dspring-boot.run.profiles=dev` | Port 8080, Flyway OK |
| 5 | Health check | `curl localhost:8080/actuator/health` | UP (db, redis, kafka) |
| 6 | ArchUnit | `mvn test -Dtest=PackageBoundaryTest` | PASS |
| 7 | All tests | `mvn test` | PASS |
| 8 | Swagger UI | `curl localhost:8080/swagger-ui.html` | 200 OK |
| 9 | Prometheus | `curl localhost:8080/actuator/prometheus` | Metrics exported |

---

## Step 15: Terraform IaC — AWS Infrastructure

**Location**: `terraform/`

### Module Summary

| Module | Resources |
|--------|-----------|
| `networking` | VPC, 3 AZ subnets (public/private-app/private-data), NAT Gateway, flow logs |
| `eks-cluster` | EKS 1.31, managed node groups (spot + on-demand), Karpenter, IRSA |
| `aurora-global` | Aurora PostgreSQL 16, writer + read replicas, Global DB, enhanced monitoring |
| `elasticache-redis` | Redis 7 cluster mode, 16 shards, Multi-AZ, encryption |
| `msk-kafka` | MSK Kafka 3.x, TLS + IAM auth |
| `opensearch` | OpenSearch 2.x, VPC access, index lifecycle |
| `ecr` | ECR repositories, lifecycle policies, image scanning |
| `waf` | WAF + Shield, OWASP CRS, rate limiting (100 req/5 min) |
| `kms` | CMKs for JWT, Aurora, Redis, S3 |
| `secrets-manager` | Secret definitions + auto-rotation |
| `appconfig` | Feature flag profiles |
| `cloudfront` | CDN distribution, Lambda@Edge, ACM cert |
| `monitoring` | CloudWatch dashboards, alarms, Synthetics canaries |

### Environments

| Environment | Region | Characteristics |
|-------------|--------|----------------|
| `dev` | us-east-1 | Small instances, single-AZ |
| `staging` | us-east-1 | Prod-like, smaller scale |
| `prod-us` | us-east-1 | Full production |
| `prod-eu` | eu-west-1 | GDPR data residency |

### State Management

- S3 backend with DynamoDB locking (`terraform/global/s3-state/`)
- Per-environment state files
- Least-privilege IAM roles per service (`terraform/global/iam-roles/`)

---

## Step 16: Kubernetes Manifests & Helm Charts

**Location**: `k8s/`

### Services

| Service | Replicas (prod) | Resources | HPA Trigger |
|---------|----------------|-----------|-------------|
| identity-service | 4-30 | 4 vCPU / 8GB | CPU 60%, 2K RPS |
| session-service | 2-10 | 2 vCPU / 4GB | Memory 70% |
| risk-engine | 2-10 | 2 vCPU / 4GB | CPU 70% |
| notification-service | 2 | 1 vCPU / 2GB | — |
| audit-service | 2 | 1 vCPU / 2GB | — |
| api-gateway | 2-10 | 2 vCPU / 4GB | CPU 60% |

### Kustomize Overlays

- `overlays/dev/` — 1 replica, minimal resources
- `overlays/staging/` — 2 replicas, medium resources
- `overlays/prod/` — Full replica counts, PodDisruptionBudgets

### Istio Service Mesh

- STRICT mTLS across namespace
- Circuit breaking via destination rules
- Admin APIs restricted to VPN

### ArgoCD GitOps

- Auto-sync for dev
- Manual sync for staging
- Canary rollout for prod: 5% → 25% → 50% → 100% with error-rate gate

---

## Step 17: CI/CD Pipeline (GitHub Actions + ArgoCD)

**Location**: `.github/workflows/`

| Workflow | Trigger | Steps |
|----------|---------|-------|
| `ci.yml` | PR to main | Compile, test, SonarQube, OWASP Dependency Check |
| `build-deploy.yml` | Push to main | Package, Docker build, Trivy scan, ECR push, ArgoCD sync dev |
| `integration-tests.yml` | After build-deploy | Testcontainers integration suite |
| `performance-test.yml` | Manual / staging deploy | Gatling load test with NFR assertions |
| `security-scan.yml` | Weekly scheduled | OWASP ZAP DAST, Trivy filesystem scan |
| `release.yml` | Manual trigger | Terraform apply, ArgoCD canary deploy, smoke test |

### CODEOWNERS

- Identity Squad: `identity/`, `shared/security/`
- Platform Team: `terraform/`, `k8s/`, `.github/workflows/`, `monitoring/`

---

## Step 18: Performance Testing Foundation (Gatling)

**Location**: `performance-tests/`

### Simulations

| Simulation | Target RPS | Duration | NFR Gates |
|-----------|-----------|----------|-----------|
| `LoginSimulation` | 10,000 | 5 min | p99 < 200ms, error < 0.1% |
| `RegistrationSimulation` | 1,000 | 5 min | p99 < 500ms, error < 0.1% |
| `TokenRefreshSimulation` | 5,000 | 5 min | p99 < 50ms, error < 0.1% |

### Running

```bash
cd performance-tests
mvn gatling:test -Dgatling.simulationClass=org.example.perf.simulations.LoginSimulation
mvn gatling:test -Dgatling.simulationClass=org.example.perf.simulations.LoginSimulation -Dbase.url=https://staging-api.ecommerce.com
```

---

## Step 19: Monitoring & Alerting (Prometheus + Grafana)

**Location**: `monitoring/`

### Prometheus Alert Rules

| Alert | Condition | Severity |
|-------|-----------|----------|
| `AuthSLOBurnRate` | Auth availability < 99.99% for 5m | Critical |
| `LoginP99High` | Login p99 > 200ms for 5m | Critical |
| `TokenValidationP99High` | Token refresh p99 > 50ms for 5m | Warning |
| `RedisHitRateLow` | Hit rate < 95% for 10m | Warning |
| `KafkaConsumerLag` | Lag > 10K messages for 5m | Warning |
| `HikariPoolExhausted` | Pool > 90% utilized for 5m | Critical |

### Grafana Dashboards

| Dashboard | Key Panels |
|-----------|-----------|
| `auth-overview` | Login rate, success/failure ratio, latency histograms |
| `session-health` | Redis hit rate, session creation/expiry, active sessions |
| `auth-slo` | 30-day availability, error budget, burn rate |
| `kafka-events` | Publish rate by topic, consumer lag, DLT volume |
| `infrastructure` | HikariCP pool, JVM memory, CPU, GC pauses |
| `security` | Lockout rate, rate-limit triggers, failed logins |

### Local Monitoring Stack

```bash
docker-compose -f monitoring/docker-compose.monitoring.yml up -d
# Grafana: http://localhost:3000 (admin/admin)
# Prometheus: http://localhost:9090
```

---

## Step 20: Full Verification & Runbook

| # | Check | Command / Action | Expected Result |
|---|-------|-----------------|-----------------|
| 1 | Dependencies | `mvn dependency:resolve` | BUILD SUCCESS |
| 2 | Compilation | `mvn compile` | BUILD SUCCESS |
| 3 | Docker infra | `docker-compose up -d` | 4 containers healthy |
| 4 | App starts | `mvn spring-boot:run -Dspring-boot.run.profiles=dev` | Port 8080, Flyway OK |
| 5 | Health check | `curl localhost:8080/actuator/health` | UP (db, redis, kafka) |
| 6 | ArchUnit | `mvn test -Dtest=PackageBoundaryTest` | PASS |
| 7 | All tests | `mvn test` | PASS |
| 8 | Swagger UI | `curl localhost:8080/swagger-ui.html` | 200 OK |
| 9 | Prometheus | `curl localhost:8080/actuator/prometheus` | Metrics exported |
| 10 | Terraform | `cd terraform/environments/dev && terraform plan` | Plan: N resources |
| 11 | K8s manifests | `kustomize build k8s/overlays/dev` | Valid YAML output |
| 12 | CI pipeline | Push PR → GitHub Actions CI runs | Green checks |
| 13 | Gatling smoke | `cd performance-tests && mvn gatling:test` | Report generated |
| 14 | Monitoring | `docker-compose -f monitoring/docker-compose.monitoring.yml up -d` | Grafana at :3000 |

---

## Files Created/Modified Summary

| Area | Action | Files |
|------|--------|-------|
| **Build** | Modified | `pom.xml` |
| **Config** | Created | `application.yml`, `application-dev.yml`, `application-test.yml`, `application-staging.yml`, `application-prod.yml` |
| **Migrations** | Created | `V1__create_schemas.sql`, `V2__create_identity_tables.sql`, `V3__create_audit_tables.sql`, `V4__create_indexes.sql` |
| **Logging** | Created | `logback-spring.xml` |
| **Security** | Created | `SecurityConfig.java`, `PasswordEncoderConfig.java`, `JwtConfig.java`, `CorsConfig.java`, dev RSA key pair |
| **Shared** | Created | `RedisConfig`, `KafkaTopicConfig`, `KafkaConfig`, `JpaAuditingConfig`, `ObservabilityConfig`, `MdcFilter`, `OpenApiConfig` |
| **Domain** | Created | `CustomerId`, `DeviceInfo`, `AbstractAuditableEntity`, `DomainEvent`, `DomainEventPublisher`, `KafkaDomainEventPublisher` |
| **DTOs** | Created | `ApiResponse`, `ErrorResponse`, `ValidationError` |
| **Exceptions** | Created | `ErrorCode`, `BusinessException`, `ResourceNotFoundException`, `GlobalExceptionHandler` |
| **Packages** | Created | 45 `package-info.java` files across shared, identity, profile, notification, audit |
| **Docker** | Created | `Dockerfile`, `docker-compose.yml`, `.dockerignore` |
| **Tests** | Created | `PackageBoundaryTest`, `CodingConventionTest`, `BaseIntegrationTest`, `application-test.yml` |
| **Terraform** | Created | `terraform/` tree (~50 .tf files across 15 modules and 4 environments) |
| **Kubernetes** | Created | `k8s/` tree (base manifests, overlays, Istio configs, ArgoCD apps) |
| **CI/CD** | Created | 5 GitHub Actions workflows, `CODEOWNERS` |
| **Perf Tests** | Created | `performance-tests/` (Gatling Maven project, 3 simulations) |
| **Monitoring** | Created | `monitoring/` (Prometheus rules, 6 Grafana dashboards, AlertManager, docker-compose) |

---

## Excluded from Scope

- **EPIC-006** (Biometric Authentication) — Removed from architecture
- **EPIC-019** (Apple Sign-In) — Removed from architecture
- **Business logic** for any epic — This foundation is infrastructure only
