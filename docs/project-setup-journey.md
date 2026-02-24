# ECommerce CIAM Platform — Project Setup Journey

> **Audience:** New team members or anyone re-setting up this project for a new service.
> **Purpose:** Documents the complete journey — from the first line of thought to the current infrastructure-ready state — including every tool used, every complexity hit, and every fix applied.

---

## 1. Project at a Glance

| Attribute | Value |
|---|---|
| **Project Name** | ECommerce CIAM (Customer Identity and Access Management) |
| **Domain** | E-Commerce — Authentication & Identity Platform |
| **Tech Stack** | Spring Boot 3.4.2 / Java 21 / PostgreSQL 16 / Redis 7 / Kafka 3.x |
| **Cloud Target** | AWS EKS (primary), Azure (EU compliance), GCP (ML/analytics) |
| **Current State** | Technical foundation complete — no business logic yet |
| **Commit 1** | `6f70b17` — first commit (bare Spring Boot shell) — Feb 20, 2026 |
| **Commit 2** | `a8329a2` — Infrastructure setup complete — Feb 20, 2026 |

---

## 2. Where It All Started — Requirements Phase (Feb 18–19, 2026)

### 2.1 The Starting Point

The project began as a **bare Spring Boot project** generated via IntelliJ/Spring Initializr with only:
- `ECommerceApplication.java` (main entry point)
- `ECommerceApplicationTests.java` (empty test)
- A basic `pom.xml` with Spring Web, Spring Data JPA, and PostgreSQL driver
- Default `application.properties`

**The problem:** There was no direction — what kind of e-commerce system? What scale? What security requirements?

### 2.2 Functional Requirements Document (FRD)

The first major work was producing a detailed **Functional Requirements Document**:

- **File produced:** `docs/customer-auth-complete-functional-requirements.md` (149 KB — the largest doc in the project)
- **Scope:** 19 sections, 50+ detailed FR IDs covering every auth scenario
- **Key NFRs locked in at this stage:**

| NFR | Target Value |
|---|---|
| Availability SLA | 99.99% (~52 min downtime/year) |
| Concurrent logins | 10,000 req/sec |
| Registered customers | 100 million |
| Daily active users | 10 million |
| Concurrent sessions | 5 million |
| Login events/day | 50 million |
| Token validation latency | < 50ms |
| Session lookup latency | < 10ms |
| RTO | < 15 minutes |
| RPO | < 1 minute |

- **Compliance scope defined:** GDPR, CCPA, CAN-SPAM, TCPA, CASL
- **Security constraints set:** bcrypt cost ≥ 12, RS256/2048-bit keys, AES-256 at rest, TLS 1.2+

### 2.3 Epics Derived from FRDs

From 53 activity diagrams, **53 epics** were identified and documented:

- **File produced:** `docs/epics-customer-registration-authentication-system.md` (75 KB)
- **Priority breakdown:** P0 Critical, P1 High, P2 Medium
- Critical P0 epics: Email Registration, Phone Registration, Email/Password Auth, Session Management, Rate Limiting, Password Policy, MFA Enrollment & Verification, Social Auth (Google), Account Lockout, Token Management, Error Handling, Audit Logging, GDPR Deletion

---

## 3. Architecture Phase (Feb 19, 2026)

### 3.1 Enterprise Architecture Design Prompt

A detailed architecture prompt was created first to guide the design:
- **File:** `docs/enterprise-architecture-design-prompt.md` (5.3 KB)

### 3.2 Technology Stack Decision Document

- **File:** `docs/customer-auth-tech-stack-spring-java.md` (39 KB)
- **Key tech decisions made vs alternatives considered:**

| Concern | Chosen | Rejected & Why |
|---|---|---|
| Threading model | Java 21 Virtual Threads (Spring MVC) | WebFlux — reactive complexity not justified |
| DB access | Spring Data JPA + Hibernate 6 | R2DBC — unnecessary with virtual threads |
| Session store | Redis (ElastiCache) | DB-backed — too slow for < 10ms target |
| Config server | AWS AppConfig | Spring Cloud Config Server — extra infra to operate |
| Secrets | AWS Secrets Manager | HashiCorp Vault — additional OSS infra |
| Service mesh | Istio | AWS App Mesh — less rich traffic management |

### 3.3 Architecture Design (Primary)

- **File:** `docs/architecture-design.md` (38 KB) — Version 1.1, Status: Approved
- **Key architectural style decided:** Federated Microservices — but starting as a **Modular Monolith** with hard package boundaries (enforced by ArchUnit), then extracting microservices per phase.

**Rationale for phased approach:**
- Phase 1 (Months 1–3): Modular monolith — boundaries validated cheaply
- Phase 2 (Month 4): Extract `identity-service` as first standalone microservice
- Phase 3 (Months 5–9): Extract `notification-service`, `audit-service`, `risk-engine`
- Phase 4 (Months 10–12): Commerce domains (catalog, orders, payment)

**Bounded Contexts identified:**
1. Identity & Access (this codebase — current focus)
2. Customer Profile
3. Notification
4. Audit & Compliance
5. Product Catalog (future)
6. Order Management (future)
7. Payment (future)
8. Seller Management (future)

**5 Architecture Decision Records (ADRs) written:**

| ADR | Decision |
|---|---|
| ADR-001 | JWT RS256 over HS256 — asymmetric; private key stays in KMS; stateless validation |
| ADR-002 | Aurora Global DB — only managed PostgreSQL meeting RPO < 1 min |
| ADR-003 | Redis for sessions — < 10ms lookup; 5M concurrent; individually revocable |
| ADR-004 | Kafka for domain events — audit writes must not block login response |
| ADR-005 | Google + Facebook only for social auth — Apple removed from scope |

### 3.4 Hybrid Cloud Architecture (Alternative View)

- **File:** `docs/hybrid-cloud-architecture-design.md` (54 KB) — Draft
- Explored a **three-cloud strategy** (AWS + Azure + GCP) with each cloud assigned where it holds a genuine advantage:

| Provider | Assignment Rationale |
|---|---|
| **AWS** (primary) | EKS, Aurora, ElastiCache Redis, MSK Kafka, KMS, Secrets Manager, CloudFront, WAF, OpenSearch, ECR, AppConfig |
| **Azure** | Enterprise SSO (Azure AD External Identities), EU Sovereign Key Vault, Azure Front Door, Application Insights APM |
| **GCP** | reCAPTCHA Enterprise (Google's own product), Vertex AI Risk Engine, BigQuery analytics, Chronicle SIEM |

---

## 4. Technical Foundation Setup (Feb 19–20, 2026)

This was the core implementation phase — 20 sequential steps to build the technical foundation. Documented in `docs/technical-foundation-setup-guide.md`.

### Step 1: Maven Dependencies & Build Configuration

**File modified:** `pom.xml`

**Starting state:** Basic Spring Boot parent with web, JPA, postgresql.
**End state:** Production-grade dependency set across 12 concerns.

**Dependencies added:**

| Area | Libraries Added |
|---|---|
| Security | `spring-boot-starter-security`, `spring-boot-starter-oauth2-resource-server`, `spring-security-oauth2-authorization-server:1.4.1` |
| Redis | `spring-boot-starter-data-redis` |
| Kafka | `spring-kafka` |
| Resilience | `resilience4j-spring-boot3:2.2.0`, `bucket4j_jdk17-core:8.10.1` |
| Observability | `spring-boot-starter-actuator`, `micrometer-registry-prometheus`, `logstash-logback-encoder:8.0` |
| API Docs | `springdoc-openapi-starter-webmvc-ui:2.8.4` |
| Mapping | `mapstruct:1.6.3` |
| MFA | `totp:1.7.1` (dev.samstevens) |
| Phone validation | `libphonenumber:8.13.27` |
| Testing | `spring-security-test`, `spring-kafka-test`, `h2`, Testcontainers BOM:1.20.4, `archunit-junit5:1.3.0` |

**Build plugins configured:**
- `maven-compiler-plugin` — Java 21, MapStruct annotation processor with `defaultComponentModel=spring`
- `flyway-maven-plugin` — multi-schema (public, identity, audit)
- `maven-failsafe-plugin` — integration test execution
- `spring-boot-maven-plugin` — layered JAR for Docker cache optimization

---

### Step 2: Modular Monolith Package Structure

**Problem:** The original project had a flat `org.example` package — no separation of concerns, impossible to evolve into microservices.

**Solution:** A strict package hierarchy enforced by ArchUnit at test time:

```
org.example
├── shared/          # Cross-cutting; must NOT import from bounded contexts
│   ├── config/
│   ├── domain/
│   ├── event/
│   ├── exception/
│   ├── dto/
│   ├── security/
│   ├── persistence/
│   └── util/
├── identity/        # Authentication bounded context
├── profile/         # Customer profile bounded context
├── notification/    # Notification bounded context
└── audit/           # Audit logging bounded context
```

**45 `package-info.java` files created** — one per package — documenting purpose and allowed dependencies. This is the canonical source of package-level contracts.

**Dependency rules enforced by ArchUnit:**
- Bounded contexts (identity, profile, notification, audit) must NOT import each other
- `shared` must NOT import any bounded context
- Controllers must NOT access repositories directly
- Cross-context communication via domain events (Kafka) only

---

### Step 3: Application Configuration (YAML)

**Problem:** Default `application.properties` was empty. Tests would fail without a database.

**Actions taken:**
- Deleted: `application.properties`, `application-test.properties`
- Created: `application.yml`, `application-dev.yml`, `application-test.yml`, `application-staging.yml`, `application-prod.yml`

**Key non-default settings that matter:**

| Setting | Value | Why |
|---|---|---|
| `spring.threads.virtual.enabled` | `true` | Java 21 Virtual Threads for 10K req/s without WebFlux |
| `spring.jpa.open-in-view` | `false` | Prevents lazy loading anti-pattern leaking into controllers |
| `hibernate.ddl-auto` | `validate` / `none` | Flyway owns schema — Hibernate must not touch it |
| `spring.flyway.schemas` | `public,identity,audit` | Multi-schema migration support |
| `jackson.default-property-inclusion` | `non_null` | Clean API responses |
| `server.shutdown` | `graceful` | Allow in-flight requests to complete during pod termination |

**Profile matrix:**

| Profile | DB | Redis | Logging |
|---|---|---|---|
| `dev` | PostgreSQL localhost | Standalone | DEBUG, console |
| `test` | H2 in-memory (PostgreSQL mode) | disabled | WARN only |
| `staging` | Aurora | Cluster | INFO, JSON |
| `prod` | Aurora Global | 16-shard cluster | INFO, JSON (Logstash) |

---

### Step 4: Database Foundation (Flyway Migrations)

**Files created:** `src/main/resources/db/migration/`

| Migration | What It Does |
|---|---|
| `V1__create_schemas.sql` | `CREATE SCHEMA identity; CREATE SCHEMA audit;` |
| `V2__create_identity_tables.sql` | `customer`, `device`, `mfa_secret`, `social_link`, `password_history`, `consent` tables |
| `V3__create_audit_tables.sql` | `audit.audit_log` with `PARTITION BY RANGE (event_time)` + monthly child partitions |
| `V4__create_indexes.sql` | Unique `LOWER(email)` index, composite indexes, covering indexes |

**Design decisions:**
- UUID primary keys via `gen_random_uuid()` — avoids sequential ID exposure
- `version` column on every table — optimistic locking
- All DDL in `identity.*` and `audit.*` schemas — never `public`
- Expand-contract pattern for zero-downtime migrations

**Complexity: Flyway + multi-schema**
- The `flyway.schemas` property must list all schemas in order
- `baseline-on-migrate: true` was needed because the public schema already existed from PostgreSQL init
- Production flag `flyway.clean-disabled: true` prevents accidental schema wipe

---

### Step 5: Spring Security Foundation

**Files created:**

| File | Purpose |
|---|---|
| `SecurityConfig.java` | Filter chain, public endpoint whitelist, JWT resource server, stateless sessions, security headers |
| `PasswordEncoderConfig.java` | `BCryptPasswordEncoder(12)` — meets NFR-SEC bcrypt cost ≥ 12 |
| `JwtConfig.java` | `NimbusJwtDecoder` configured with RSA public key for RS256 validation |
| `CorsConfig.java` | Environment-aware CORS — dev allows `localhost:*`, prod allows `*.ecommerce.com` |

**Public endpoints whitelisted (no JWT required):**
- `/api/v1/auth/register`, `/api/v1/auth/login`, `/api/v1/auth/verify-email`
- `/api/v1/auth/forgot-password`, `/api/v1/auth/reset-password`, `/api/v1/auth/refresh-token`
- `/api/v1/auth/otp/**`
- `/actuator/health/**`, `/actuator/prometheus`, `/actuator/info`
- `/swagger-ui/**`, `/v3/api-docs/**`

**Security headers configured:**
- `Content-Security-Policy: default-src 'self'; frame-ancestors 'none'`
- `X-Frame-Options: DENY`
- `X-Content-Type-Options: nosniff`
- `Referrer-Policy: strict-origin-when-cross-origin`

**Dev RSA keys generated:**
- `src/main/resources/keys/dev-private.pem` and `dev-public.pem`
- `keys/README.md` — documents how to regenerate them
- **Important:** These are dev-only placeholder keys. In production, the private key lives in AWS KMS — it never touches the filesystem.

---

### Step 6: Redis Foundation

**File:** `shared/config/RedisConfig.java`

**Configuration:**
- `RedisTemplate<String, Object>` — Jackson JSON serialization with `JavaTimeModule` for `Instant`/`LocalDateTime`
- `StringRedisTemplate` — simple counters and rate limiter keys
- Lettuce connection factory (standalone for dev, cluster for prod)
- Connection pool: max-active 16, max-idle 8, min-idle 2, max-wait 2000ms

**Key namespace convention established:**

| Pattern | Use |
|---|---|
| `ecommerce:session:{id}` | User sessions |
| `ecommerce:ratelimit:{type}:{key}` | Rate limit counters (Bucket4j) |
| `ecommerce:otp:{customerId}` | OTP codes (5-min TTL) |
| `ecommerce:token:blacklist:{jti}` | Revoked JWT token IDs |

---

### Step 7: Kafka Foundation

**Files:** `shared/config/KafkaConfig.java`, `shared/config/KafkaTopicConfig.java`

**Topics created (with partition counts):**

| Topic | Partitions | Purpose |
|---|---|---|
| `auth.login.events` | 12 | Login success/failure |
| `auth.registration.events` | 6 | New registrations |
| `auth.password.events` | 6 | Password changes/resets |
| `auth.session.events` | 12 | Session lifecycle |
| `auth.security.events` | 6 | Lockouts, suspicious activity |
| `auth.audit.events` | 12 | Full audit trail |
| `notifications.email` | 6 | Email dispatch queue |
| `notifications.sms` | 6 | SMS dispatch queue |

**Error handling strategy:**
- `DefaultErrorHandler` with `FixedBackOff(1000L, 3)` — 3 retries, 1s apart
- `DeadLetterPublishingRecoverer` — failed messages go to `{topic}.DLT`

**Domain event infrastructure:**
- `DomainEvent` — abstract base (eventId UUID, eventType, occurredAt, customerId, metadata map)
- `DomainEventPublisher` — interface for topic-based publishing
- `KafkaDomainEventPublisher` — Kafka implementation with async send callbacks and error logging

---

### Step 8: Shared Kernel & Cross-Cutting Concerns

**Domain primitives:**

| Class | Description |
|---|---|
| `CustomerId` | Java `record` wrapping UUID — universal identifier across all bounded contexts |
| `DeviceInfo` | Java `record` — fingerprint, name, type, OS, browser, IP, userAgent |

**Persistence base:**
- `AbstractAuditableEntity` — `@MappedSuperclass` with auto-managed `id (UUID)`, `createdAt`, `updatedAt`, `version` (for optimistic locking)
- `JpaAuditingConfig` — enables `@EnableJpaAuditing`

**API response envelope standardised:**
```java
ApiResponse<T> { boolean success, T data, ErrorResponse error, String requestId, Instant timestamp }
ErrorResponse { String code, String message, List<ValidationError> details }
ValidationError { String field, String message, Object rejectedValue }
```

**Error codes defined (15 codes covering all auth failure scenarios):**

| Code | HTTP | Scenario |
|---|---|---|
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

**Global exception handler** (`@RestControllerAdvice`) — maps all exception types to structured `ApiResponse` with correct HTTP status.

---

### Step 9: Observability Foundation

**Files:** `shared/config/ObservabilityConfig.java`, `shared/config/MdcFilter.java`, `src/main/resources/logback-spring.xml`

**Request tracing:**
- `MdcFilter` (`OncePerRequestFilter`, highest precedence) — extracts or generates `X-Request-ID` header, sets `requestId` and `customerId` in MDC, echoes `X-Request-ID` back in response

**Structured logging:**
- `dev` profile: human-readable pattern with `[requestId]` prefix
- `staging`/`prod` profiles: `LogstashEncoder` JSON — all MDC fields included automatically, compatible with CloudWatch/OpenSearch ingestion via Fluent Bit
- `test` profile: WARN level only (no noise in test output)

**Metrics:**
- Common Micrometer tags applied to all metrics: `application` and `environment`
- Prometheus endpoint auto-enabled at `/actuator/prometheus`

---

### Step 10: Resilience Foundation

**Configured in `application.yml`:**

**Circuit breakers (Resilience4j):**

| Instance | Failure Threshold | Wait Duration | Use Case |
|---|---|---|---|
| `riskEngine` | 50% | 15s | Risk scoring service calls |
| `socialAuth` | 60% | 10s | Google/Facebook OAuth calls |
| `externalApi` | 50% | 10s | Generic external API calls |

**Retries:**

| Instance | Max Attempts | Backoff | Use Case |
|---|---|---|---|
| `kafkaProducer` | 5 | Exponential ×2, starting 1s | Kafka publish failures |
| `externalApi` | 3 | Exponential ×2, starting 500ms | External API calls |

**Bulkheads (semaphore-based):**
- `googleOAuth`: max 50 concurrent calls
- `facebookOAuth`: max 50 concurrent calls

**Graceful degradations designed:**
- Risk Engine down → default MEDIUM risk (require MFA)
- Redis down → new session creation disabled, existing short-lived access tokens (15 min) still work via stateless RS256 validation

---

### Step 11: API Documentation (SpringDoc OpenAPI)

**File:** `shared/config/OpenApiConfig.java`

- Bearer JWT security scheme on all protected endpoints
- Swagger UI at `/swagger-ui.html`
- OpenAPI spec at `/v3/api-docs`
- API groups: `identity`, `profile`, `audit`, `actuator`

---

### Step 12: Docker Foundation

**Dockerfile (3-stage multi-stage build):**

| Stage | Base Image | Purpose |
|---|---|---|
| `build` | `eclipse-temurin:21-jdk` | Maven compile + package |
| `extract` | `eclipse-temurin:21-jdk` | Extract layered JAR for cache |
| `runtime` | `eclipse-temurin:21-jre` | Minimal production image |

**Runtime optimisations applied:**
- Non-root user (`appuser`) — security hardening
- ZGC garbage collector (`-XX:+UseZGC -XX:+ZGenerational`) — low-latency GC pauses
- Container-aware memory (`-XX:MaxRAMPercentage=75.0 -XX:+UseContainerSupport`)
- Health check wired to `/actuator/health/liveness`

**`docker-compose.yml` for local development:**

| Service | Image | Port | Notes |
|---|---|---|---|
| PostgreSQL | `postgres:16-alpine` | 5432 | Named volume, health check |
| Redis | `redis:7-alpine` | 6379 | Named volume, ping health check |
| Kafka | `apache/kafka:3.8.0` | 9092 | **KRaft mode — no ZooKeeper** |
| OpenSearch | `opensearchproject/opensearch:2.17.1` | 9200 | Security plugin disabled for dev |

**Complexity: Kafka KRaft mode**
- The new `apache/kafka` image uses KRaft (no ZooKeeper dependency) — requires `KAFKA_CONTROLLER_QUORUM_VOTERS` and `CLUSTER_ID` env vars
- The `CLUSTER_ID` must be a valid base64-encoded 16-byte value — hardcoded a stable dev value: `MkU3OEVBNTcwNTJENDM2Qg`
- `KAFKA_ADVERTISED_LISTENERS: PLAINTEXT://localhost:9092` — containers talk to Kafka via `localhost` from the host

---

### Step 13: Testing Foundation

**ArchUnit tests (enforce architecture rules at build time):**

| Test Class | Rules Checked |
|---|---|
| `PackageBoundaryTest` | Context isolation, shared independence, controller-repository separation, no dependency cycles |
| `CodingConventionTest` | `@RestController` only in controller pkg, `@Service` only in service pkg, `@Entity` only in entity pkg, repositories are interfaces not classes |

**Integration test base:**
- `BaseIntegrationTest` — abstract class, `@SpringBootTest` + `@Testcontainers`
- Spins up real PostgreSQL 16 and Kafka containers via Testcontainers
- `@DynamicPropertySource` injects container connection details at runtime

**`application-test.yml`:**
- H2 in PostgreSQL-compatibility mode — unit tests need no Docker
- Flyway disabled for unit tests
- Session store: `none`

---

### Step 14: Application Verification Checklist

The following sequence was used to validate the entire foundation before committing:

| # | Check | Expected |
|---|---|---|
| 1 | `mvn dependency:resolve` | BUILD SUCCESS |
| 2 | `mvn compile` | BUILD SUCCESS |
| 3 | `docker-compose up -d` | 4 containers healthy |
| 4 | `mvn spring-boot:run -Dspring-boot.run.profiles=dev` | Port 8080, Flyway migrations applied |
| 5 | `curl localhost:8080/actuator/health` | UP (db, redis, kafka in components) |
| 6 | `mvn test -Dtest=PackageBoundaryTest` | PASS |
| 7 | `mvn test` | PASS |
| 8 | `curl localhost:8080/swagger-ui.html` | 200 OK |
| 9 | `curl localhost:8080/actuator/prometheus` | Metrics exported |

---

### Step 15: Terraform IaC — AWS Infrastructure

**Location:** `terraform/`

**Module structure:**

| Module | Key Resources |
|---|---|
| `networking` | VPC, 3-AZ subnets (public/private-app/private-data), NAT Gateway, VPC Flow Logs |
| `eks-cluster` | EKS 1.31, managed node groups (spot + on-demand), Karpenter autoscaler, IRSA |
| `aurora-global` | Aurora PostgreSQL 16, writer + 3 read replicas, Global Database, enhanced monitoring |
| `elasticache-redis` | Redis 7, Cluster Mode, 16 shards, Multi-AZ, TLS + at-rest encryption |
| `msk-kafka` | MSK Kafka 3.x, TLS + IAM auth, topic definitions |
| `opensearch` | OpenSearch 2.x, VPC access, index lifecycle policies |
| `ecr` | Container registries, lifecycle policies, image scanning via Inspector |
| `waf` | AWS WAF + Shield Advanced, OWASP CRS, 100 req/5-min rate rule |
| `kms` | CMKs for JWT signing, Aurora, Redis, S3 |
| `secrets-manager` | DB credentials, Redis token, OAuth client secrets — all with auto-rotation |
| `appconfig` | Feature flags (risk thresholds, MFA enforcement, social provider toggles) |
| `cloudfront` | CDN, Lambda@Edge for pre-validation, ACM certificate |
| `monitoring` | CloudWatch dashboards, alarms, Synthetics canaries (login + token refresh flows) |

**4 environments:**

| Environment | Region | Purpose |
|---|---|---|
| `dev` | us-east-1 | Small instances, single-AZ |
| `staging` | us-east-1 | Prod-like scale, smaller |
| `prod-us` | us-east-1 | Full production |
| `prod-eu` | eu-west-1 | GDPR data residency (separate Aurora cluster) |

**State management:** S3 backend with DynamoDB locking, per-environment state files.

---

### Step 16: Kubernetes Manifests (Kustomize)

**Location:** `k8s/`

**Services and pod sizing (prod):**

| Service | Prod Replicas | Resources | HPA Trigger |
|---|---|---|---|
| identity-service | 4–30 | 4 vCPU / 8GB | CPU 60% or 2K RPS |
| session-service | 2–10 | 2 vCPU / 4GB | Memory 70% |
| risk-engine | 2–10 | 2 vCPU / 4GB | CPU 70% |
| notification-service | 2 | 1 vCPU / 2GB | — |
| audit-service | 2 | 1 vCPU / 2GB | — |
| api-gateway | 2–10 | 2 vCPU / 4GB | CPU 60% |

**Kustomize overlays:**
- `overlays/dev/` — 1 replica, minimal resources
- `overlays/staging/` — 2 replicas, medium resources
- `overlays/prod/` — full replica counts, PodDisruptionBudgets

**Istio service mesh:**
- STRICT mTLS mode across the namespace
- Circuit breaking via Istio DestinationRules
- Admin APIs restricted to VPN CIDR via AuthorizationPolicy

**ArgoCD GitOps:**
- `dev` — auto-sync on every push to main
- `staging` — manual sync trigger
- `prod` — canary rollout: 5% → 25% → 50% → 100% with error-rate gate

---

### Step 17: CI/CD Pipeline (GitHub Actions + ArgoCD)

**Location:** `.github/workflows/`

| Workflow File | Trigger | What It Does |
|---|---|---|
| `ci.yml` | PR to main | Compile, unit tests, ArchUnit, SonarQube SAST, OWASP Dependency Check |
| `build-deploy.yml` | Push to main | Package, Docker build, Trivy image scan, ECR push, ArgoCD sync dev |
| `integration-tests.yml` | After build-deploy | Testcontainers integration suite |
| `performance-test.yml` | Manual / staging deploy | Gatling load test with NFR assertions (10K req/s gate) |
| `security-scan.yml` | Weekly schedule | OWASP ZAP DAST, Trivy filesystem scan |
| `release.yml` | Manual trigger | Terraform apply + ArgoCD canary deploy + smoke test |

**CODEOWNERS file:** (`/.github/CODEOWNERS`)
- Identity Squad owns: `identity/`, `shared/security/`
- Platform Team owns: `terraform/`, `k8s/`, `.github/workflows/`, `monitoring/`

---

### Step 18: Performance Testing (Gatling)

**Location:** `performance-tests/`

| Simulation | Target RPS | Duration | Pass/Fail Gates |
|---|---|---|---|
| `LoginSimulation` | 10,000 | 5 min | p99 < 200ms, error rate < 0.1% |
| `RegistrationSimulation` | 1,000 | 5 min | p99 < 500ms, error rate < 0.1% |
| `TokenRefreshSimulation` | 5,000 | 5 min | p99 < 50ms, error rate < 0.1% |

**Run commands:**
```bash
cd performance-tests
mvn gatling:test -Dgatling.simulationClass=org.example.perf.simulations.LoginSimulation
```

---

### Step 19: Monitoring & Alerting

**Location:** `monitoring/`

**Prometheus alert rules:**

| Alert Name | Condition | Severity |
|---|---|---|
| `AuthSLOBurnRate` | Auth availability < 99.99% for 5m | Critical |
| `LoginP99High` | Login p99 > 200ms for 5m | Critical |
| `TokenValidationP99High` | Token p99 > 50ms for 5m | Warning |
| `RedisHitRateLow` | Hit rate < 95% for 10m | Warning |
| `KafkaConsumerLag` | Lag > 10K messages for 5m | Warning |
| `HikariPoolExhausted` | Pool > 90% utilized for 5m | Critical |

**Grafana dashboards (6 total):**
- `auth-overview` — login rate, success/failure ratio, latency histograms
- `session-health` — Redis hit rate, session creation/expiry, active sessions
- `auth-slo` — 30-day availability, error budget, burn rate
- `kafka-events` — publish rate by topic, consumer lag, DLT volume
- `infrastructure` — HikariCP pool, JVM memory, CPU, GC pauses
- `security` — lockout rate, rate-limit triggers, failed login map

**Local monitoring stack:**
```bash
docker-compose -f monitoring/docker-compose.monitoring.yml up -d
# Grafana: http://localhost:3000 (admin/admin)
# Prometheus: http://localhost:9090
```

---

## 5. Complexities Faced & How They Were Fixed

### Complexity 1: bcrypt at Cost 12 vs 10K logins/sec

**Problem:** bcrypt at cost 12 takes ~100ms per hash on commodity hardware. At 10,000 logins/sec, a single pod would need 1,000 concurrent hashing threads.

**How it was addressed in design:**
- Architecture dedicated a `VirtualThreadExecutor` pool specifically for CPU-bound bcrypt work, isolated from I/O threads
- Pod sizing: 20 pods × 500 RPS/pod target (Java 21 virtual threads, 4 vCPU / 8GB RAM each)
- A **week-2 spike** was mandated in the roadmap to validate actual bcrypt throughput before locking in pod counts

**Status:** Design solution documented. Validation spike is a P0 pre-Phase-1 deliverable.

---

### Complexity 2: RPO < 1 Minute with PostgreSQL

**Problem:** Standard PostgreSQL async streaming replication has 1–10s lag and requires manual failover — cannot meet RPO < 1 min + RTO < 15 min.

**Fix:** Amazon Aurora Global Database — designed for < 1 second cross-region replication with automated managed failover.

**Trade-off accepted:** AWS vendor lock-in; ~3× cost vs standard RDS. Documented in ADR-002. Alternative (CockroachDB) was rejected because it adds operational complexity for greenfield project.

---

### Complexity 3: Kafka KRaft Mode Configuration

**Problem:** The modern `apache/kafka:3.8.0` image uses KRaft (no ZooKeeper), but its environment variables are not well-documented compared to the Confluent images. The initial compose setup failed to start.

**Fix:** Found and configured the exact required environment variables:
```yaml
KAFKA_NODE_ID: 1
KAFKA_PROCESS_ROLES: broker,controller
KAFKA_LISTENERS: PLAINTEXT://0.0.0.0:9092,CONTROLLER://0.0.0.0:9093
KAFKA_ADVERTISED_LISTENERS: PLAINTEXT://localhost:9092
KAFKA_CONTROLLER_LISTENER_NAMES: CONTROLLER
KAFKA_LISTENER_SECURITY_PROTOCOL_MAP: CONTROLLER:PLAINTEXT,PLAINTEXT:PLAINTEXT
KAFKA_CONTROLLER_QUORUM_VOTERS: 1@localhost:9093
CLUSTER_ID: 'MkU3OEVBNTcwNTJENDM2Qg'   # must be a valid base64-encoded 16-byte value
```
Also required setting `KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR: 1` for single-node dev cluster.

---

### Complexity 4: Flyway Multi-Schema with PostgreSQL

**Problem:** Flyway by default only manages the `public` schema. The project needs `identity` and `audit` schemas. Without explicit schema creation in V1, later migrations fail because the schemas don't exist.

**Fix:**
- `V1__create_schemas.sql` creates `identity` and `audit` schemas first, before any tables
- `spring.flyway.schemas: public,identity,audit` — tells Flyway to track all three
- `baseline-on-migrate: true` — required because the PostgreSQL init already created `public`
- `flyway.clean-disabled: true` in prod — prevents catastrophic `flyway:clean` on live data

---

### Complexity 5: MapStruct + Spring Annotation Processor Ordering

**Problem:** MapStruct requires its annotation processor to run before the Spring compiler. Without explicit ordering, generated mapper classes may not be Spring-managed beans.

**Fix in `pom.xml`:**
```xml
<annotationProcessorPaths>
    <path>
        <groupId>org.mapstruct</groupId>
        <artifactId>mapstruct-processor</artifactId>
        <version>1.6.3</version>
    </path>
</annotationProcessorPaths>
<compilerArgs>
    <arg>-Amapstruct.defaultComponentModel=spring</arg>
</compilerArgs>
```
The `-Amapstruct.defaultComponentModel=spring` flag makes all generated mappers `@Component` beans automatically.

---

### Complexity 6: Spring Security + JWT Resource Server Configuration

**Problem:** Spring Security 6 has breaking changes from Spring Security 5. The JWT resource server auto-configuration requires explicit configuration of the decoder. Without it, all endpoints return 401.

**Fix:** `JwtConfig.java` — explicitly constructs a `NimbusJwtDecoder` from the RSA public key. For production, this connects to AWS KMS's JWKS endpoint instead. The `SecurityConfig.java` references this bean in the filter chain.

Additionally, OpenAPI and Actuator endpoints had to be explicitly added to the permit-all list — Spring Security 6 denies by default (unlike earlier versions).

---

### Complexity 7: Docker Layered JAR + Spring Boot 3.x

**Problem:** Spring Boot 3.x changed the JAR launcher class from `JarLauncher` to `launch.JarLauncher`. Docker `ENTRYPOINT` using the old class name would fail to start.

**Fix in Dockerfile:**
```dockerfile
ENTRYPOINT ["sh", "-c", "java $JAVA_OPTS org.springframework.boot.loader.launch.JarLauncher"]
```
The `launch.JarLauncher` path is the correct path for Spring Boot 3.x.

---

### Complexity 8: Audit Log Volume (9 Billion Rows)

**Problem:** 50M events/day × 180 days = ~9 billion rows. A single PostgreSQL table at this scale is unmanageable.

**Fix:** PostgreSQL table partitioning by range on `event_time`:
- `V3__create_audit_tables.sql` — creates the parent table with `PARTITION BY RANGE (event_time)`
- Monthly child partitions pre-created for the initial window
- A scheduled job runs on the 1st of each month: drops the 7-month-old partition (enforcing 6-month retention) and creates the next month's partition
- OpenSearch indexed the same events for customer-facing login history queries (full-text + date-range)

---

### Complexity 9: ArchUnit Tests Failing Due to Package Structure

**Problem:** ArchUnit checks failed initially because some `package-info.java` files were missing and the rule for "controllers must not access repositories directly" was too broad — it flagged Spring's internal classes.

**Fix:**
- Scoped ArchUnit rules to `org.example..` package only
- Added `package-info.java` in every package (45 files total)
- Rules refined to check `@RestController`-annotated classes rather than all classes in the controller package

---

### Complexity 10: Apple Sign-In Removal Mid-Architecture

**Problem:** Apple Sign-In was initially planned (EPIC-019). During architecture review, it was removed — but the FRD references remained, and the OAuth client dependency would have added complexity.

**Fix:**
- `architecture-design.md` v1.1 explicitly documents the removal
- `SocialAuthProvider` interface was designed to allow future re-addition as an additive change (no core changes needed)
- EPIC-019 marked P1-High but excluded from Phase 1–3 deliverables
- The risk was logged: iOS App Store mandates Apple Sign-In if any social login is offered — this is R-007 in the Risk Register

---

## 6. Files Created — Complete Inventory

| Area | Files |
|---|---|
| **Build** | `pom.xml` (modified) |
| **Config** | `application.yml`, `application-dev.yml`, `application-test.yml`, `application-staging.yml`, `application-prod.yml` |
| **DB Migrations** | `V1__create_schemas.sql`, `V2__create_identity_tables.sql`, `V3__create_audit_tables.sql`, `V4__create_indexes.sql` |
| **Security** | `SecurityConfig.java`, `PasswordEncoderConfig.java`, `JwtConfig.java`, `CorsConfig.java`, `dev-private.pem`, `dev-public.pem`, `keys/README.md` |
| **Config beans** | `RedisConfig.java`, `KafkaTopicConfig.java`, `KafkaConfig.java`, `JpaAuditingConfig.java`, `ObservabilityConfig.java`, `MdcFilter.java`, `OpenApiConfig.java` |
| **Domain** | `CustomerId.java`, `DeviceInfo.java`, `AbstractAuditableEntity.java` |
| **Events** | `DomainEvent.java`, `DomainEventPublisher.java`, `KafkaDomainEventPublisher.java` |
| **DTOs** | `ApiResponse.java`, `ErrorResponse.java`, `ValidationError.java` |
| **Exceptions** | `ErrorCode.java`, `BusinessException.java`, `ResourceNotFoundException.java`, `GlobalExceptionHandler.java` |
| **Packages** | 45 × `package-info.java` across `shared`, `identity`, `profile`, `notification`, `audit` |
| **Logging** | `logback-spring.xml` |
| **Docker** | `Dockerfile`, `docker-compose.yml`, `.dockerignore` |
| **Tests** | `PackageBoundaryTest.java`, `CodingConventionTest.java`, `BaseIntegrationTest.java`, `application-test.yml` |
| **Terraform** | ~50 `.tf` files across 13 modules + 4 environments + global state |
| **Kubernetes** | `k8s/` tree — base manifests, Kustomize overlays (dev/staging/prod), Istio configs, ArgoCD apps |
| **CI/CD** | 6 GitHub Actions workflow `.yml` files, `CODEOWNERS` |
| **Performance** | `performance-tests/` — Gatling Maven project, 3 simulation classes |
| **Monitoring** | `monitoring/` — Prometheus rules, 6 Grafana dashboard JSONs, AlertManager config, `docker-compose.monitoring.yml` |
| **Docs** | `CLAUDE.md`, `architecture-design.md`, `customer-auth-complete-functional-requirements.md`, `customer-auth-tech-stack-spring-java.md`, `enterprise-architecture-design-prompt.md`, `epics-customer-registration-authentication-system.md`, `hybrid-cloud-architecture-design.md`, `technical-foundation-setup-guide.md` |

---

## 7. Tools Used

| Tool / Technology | Version | Role in Project |
|---|---|---|
| **IntelliJ IDEA** | — | IDE; initial project generation |
| **Spring Initializr** | — | Bootstrapped the Maven project |
| **Java** | 21 LTS | Application runtime; Virtual Threads |
| **Spring Boot** | 3.4.2 | Application framework |
| **Maven** | 3.x | Build system |
| **Spring Security** | 6.x | Auth filter chain, JWT resource server |
| **Spring Authorization Server** | 1.4.1 | OAuth2/OIDC token issuer |
| **Flyway** | 10.21.0 | Database schema migrations |
| **Hibernate / JPA** | 6.x | ORM |
| **MapStruct** | 1.6.3 | Compile-time DTO mapping |
| **Resilience4j** | 2.2.0 | Circuit breaker, retry, bulkhead |
| **Bucket4j** | 8.10.1 | Token-bucket rate limiting (Redis-backed) |
| **Nimbus JOSE+JWT** | 9.x | RS256 JWT creation and validation |
| **dev.samstevens TOTP** | 1.7.1 | TOTP MFA library |
| **libphonenumber** | 8.13.27 | Phone number validation and normalisation |
| **Micrometer** | managed | Metrics facade |
| **Logstash Logback Encoder** | 8.0 | JSON structured logging |
| **SpringDoc OpenAPI** | 2.8.4 | Swagger UI + OpenAPI 3 spec generation |
| **ArchUnit** | 1.3.0 | Architecture tests at build time |
| **Testcontainers** | 1.20.4 | Real containers in integration tests |
| **H2 Database** | — | In-memory DB for unit tests |
| **PostgreSQL** | 16 | Primary relational database |
| **Redis** | 7 | Session store, rate limiting, OTP, token blacklist |
| **Apache Kafka** | 3.8.0 (KRaft) | Domain event bus |
| **OpenSearch** | 2.17.1 | Login history full-text search |
| **Docker** | — | Containerisation |
| **docker-compose** | 3.9 | Local dev infrastructure |
| **Kubernetes** | 1.31 | Production container orchestration |
| **Kustomize** | — | K8s overlay management (dev/staging/prod) |
| **Istio** | — | Service mesh, mTLS, circuit breaking |
| **ArgoCD** | — | GitOps continuous deployment |
| **Terraform** | — | Infrastructure as Code (AWS) |
| **AWS EKS** | — | Managed Kubernetes |
| **AWS Aurora PostgreSQL** | 16 compat | Global Database, managed failover |
| **AWS ElastiCache** | Redis 7 | Managed Redis cluster |
| **AWS MSK** | Kafka 3.x | Managed Kafka |
| **AWS KMS** | — | JWT signing key, envelope encryption |
| **AWS Secrets Manager** | — | DB credentials, API keys, auto-rotation |
| **AWS AppConfig** | — | Feature flags, runtime config |
| **AWS WAF + Shield** | — | DDoS protection, OWASP rules |
| **Amazon CloudFront** | — | CDN + Lambda@Edge |
| **GitHub Actions** | — | CI pipeline |
| **Prometheus** | — | Metrics collection |
| **Grafana** | — | Dashboards, SLO tracking, alerting |
| **Gatling** | — | Load testing (10K req/s validation) |
| **Git** | — | Version control |
| **Claude Code** | — | AI pair programmer — architecture, code, docs |

---

## 8. What Is NOT Done Yet (Next Steps)

The current codebase is **infrastructure only** — the foundation is complete, but no business logic exists.

**What remains (by phase):**

**Phase 1 (Months 1–3) — Foundation business logic:**
- Customer entity, email registration (EPIC-001)
- Email/password authentication, bcrypt + JWT issuance (EPIC-004)
- Session management with Redis (EPIC-008)
- Rate limiting with Bucket4j (EPIC-007)
- Account lockout (EPIC-035)
- Audit logging via Kafka (EPIC-045)
- Notification Service skeleton (EPIC-042)

**Phase 2 (Months 4–6):**
- Phone OTP registration and auth (EPIC-002, EPIC-005)
- TOTP MFA enrollment and verification (EPIC-014, EPIC-015)
- Google OAuth / OIDC social auth (EPIC-017)
- Facebook OAuth (EPIC-018)
- Password reset flows (EPIC-012)

**Phase 3 (Months 7–9):**
- Risk Engine (EPIC-036)
- Device management (EPIC-033, EPIC-034)
- GDPR compliance — data export, account deletion, consent (EPIC-041, EPIC-046, EPIC-047)

**Phase 4 (Months 10–12):**
- Product Catalog, Order Management, Payment, Seller Management services

**Excluded from scope (permanently removed):**
- EPIC-006 — Biometric Authentication
- EPIC-019 — Apple Sign-In (additive if iOS app is planned in future)

---

## 9. Quick Setup Guide for New Service

If you are setting up this project for a different service context, here is what to adapt:

### Change These First

| Item | Location | What to Change |
|---|---|---|
| Application name | `application.yml` → `spring.application.name` | Rename from `ecommerce-ciam` |
| Package name | `pom.xml` `<groupId>`, `src/main/java/` | Change from `org.example` |
| DB name | `docker-compose.yml` → `POSTGRES_DB`, `application-dev.yml` | Change from `ecommerce_db` |
| Kafka topics | `KafkaTopicConfig.java` | Replace with your domain topics |
| Error codes | `ErrorCode.java` | Replace with your domain error codes |
| Bounded context packages | `src/main/java/org/example/{identity,profile,notification,audit}` | Replace with your bounded contexts |
| Flyway schemas | `application.yml` → `spring.flyway.schemas` | Replace `identity,audit` with your schemas |
| Redis key prefix | `RedisConfig.java` and usage | Change `ecommerce:` prefix |

### Keep These As-Is

| Item | Why |
|---|---|
| `AbstractAuditableEntity` | Universal auditing pattern |
| `ApiResponse` / `ErrorResponse` envelope | Consistent API contract |
| `GlobalExceptionHandler` | Robust error handling |
| `MdcFilter` + structured logging | Distributed tracing pattern |
| `ObservabilityConfig` | Micrometer tagging |
| `SecurityConfig` base structure | Spring Security 6 setup |
| Dockerfile structure | Optimised layered build |
| ArchUnit test structure | Replace rule subjects, keep the pattern |
| Testcontainers `BaseIntegrationTest` | Works for any service with PostgreSQL + Kafka |

### Local Startup (After Clone)

```bash
# 1. Start infrastructure
docker-compose up -d

# 2. Wait for health (all 4 containers)
docker-compose ps

# 3. Run application
mvn spring-boot:run -Dspring-boot.run.profiles=dev

# 4. Verify
curl http://localhost:8080/actuator/health
curl http://localhost:8080/swagger-ui.html

# 5. Run tests
mvn test
```

---

*Document generated: February 24, 2026*
*Current branch: `main`*
*Last commit: `a8329a2` — Infrastructure setup*
