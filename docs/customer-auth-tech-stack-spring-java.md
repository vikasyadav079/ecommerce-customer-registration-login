**ENTERPRISE TECHNOLOGY STACK**

Customer Registration & Authentication System

**Java / Spring Framework Edition**

Version 2.1 \| February 2026 \| Solution Architecture Team

---

**Change Log — v2.1**

The following changes have been applied relative to v2.0 based on a cross-comparison with the architecture assessment in `architecture-design.md`:

| Change | Detail |
|--------|--------|
| ❌ Removed | Apple Sign-In — out of scope for this release |
| ❌ Removed | Biometric authentication (Face ID, BiometricPrompt, WebAuthn) — out of scope |
| ✅ Retained | Spring Authorization Server over plain Spring Security OAuth2 — correct for token issuance |
| ✅ Retained | Spring Cloud Gateway over Kong / AWS API GW — better Spring ecosystem fit |
| ✅ Retained | Istio over AWS App Mesh — richer observability and mTLS |
| ⚠️ Overridden | Jib → **Docker** (standard Dockerfile) |
| ✅ Retained | com.warrenstrange:googleauth for TOTP |
| ⚠️ Overridden | Spring WebFlux → **Spring MVC + Java 21 Virtual Threads** — same throughput, simpler imperative model |
| ⚠️ Overridden | Spring Cloud Config Server → **AWS AppConfig** — serverless, no extra service to operate |
| ⚠️ Overridden | HashiCorp Vault → **AWS Secrets Manager + AWS KMS** — AWS-native, no Vault cluster |
| ⚠️ Overridden | LaunchDarkly → **AWS AppConfig feature flags** — simpler for initial needs |
| ⚠️ Overridden | Spring Data R2DBC → **Spring Data JPA + HikariCP** — R2DBC unnecessary with virtual threads |
| 📅 Updated | Audit log retention: 7 years → **6 months** |
| 🔢 Updated | Spring Boot version: 3.3.x → **3.4.2** |

---

  -----------------------------------------------------------------------
**Attribute**          **Value**
  ---------------------- ------------------------------------------------
Document Title         Enterprise Technology Stack - Customer Auth
System

Version                2.0

Status                 Draft

Date                   February 18, 2026

Author                 Solution Architecture Team

Target Scale           100M users, 10M DAU, 50M logins/day

Backend Framework      Java 21 + Spring Boot 3.x (Migration from
Node.js/Go)
  -----------------------------------------------------------------------

**1. Executive Summary**

**1.1 Overview**

This document outlines the updated enterprise-level technology stack for
the Customer Registration and Authentication system, migrated to Java 21
with Spring Boot 3.x as the primary backend framework. Spring Boot\'s
mature ecosystem, enterprise-grade patterns, and proven scalability make
it an ideal choice for authentication-critical workloads at scale.

  -----------------------------------------------------------------------
**Requirement**    **Target**         **Technology Focus**
  ------------------ ------------------ ---------------------------------
Scale              100 million        Spring Cloud + Distributed DBs
registered users

Throughput         10,000             Reactive Spring WebFlux
logins/second

Availability       99.99% uptime      Multi-region deployment

Security           Enterprise-grade   Spring Security, Zero-trust

Compliance         GDPR, SOC 2, PCI   Audit logging, data protection
DSS

Performance        \<2s login         Spring Cache, Redis, CDN
response
  -----------------------------------------------------------------------

**1.2 Why Java / Spring Boot?**

Spring Boot 3.x with Java 21 offers virtual threads (Project Loom),
reactive programming via WebFlux, and Spring Security --- a
battle-tested authentication framework. The Spring ecosystem provides
Spring Cloud Gateway, Spring Data, Spring Session, and Spring
Authorization Server out of the box, significantly reducing custom
development effort.

  -----------------------------------------------------------------------
**Advantage**          **Detail**
  ---------------------- ------------------------------------------------
Spring Security        Native OAuth2, JWT, MFA, session management
built-in

Virtual Threads (Loom) Java 21 virtual threads handle 10K+ concurrent
requests with minimal overhead

Spring WebFlux         Reactive non-blocking I/O for high-throughput
auth endpoints

Spring Authorization   Standards-compliant OAuth2/OIDC server, replaces
Server                 custom auth logic

Spring Cloud           Mature microservices toolkit: Gateway, Config,
Discovery, Vault

Enterprise Ecosystem   Vast talent pool, long-term Oracle/Spring
support, SOC2 tooling
  -----------------------------------------------------------------------

**2. Backend Technology Stack**

**2.1 Primary Language & Framework**

  --------------------------------------------------------------------------
**Component**   **Technology**     **Version**   **Rationale**
  --------------- ------------------ ------------- -------------------------
Language        Java               21 LTS        Virtual threads, records,
pattern matching,
long-term support

Framework       Spring Boot        3.4.2         Auto-configuration,
production-ready, vast
ecosystem

Concurrency     Java 21 Virtual    Loom          Replaces reactive WebFlux for
Threads (Loom)               auth/session — same throughput,
imperative model

MVC Stack       Spring MVC         6.x           Servlet-based with virtual
thread executor (all services)

Security        Spring Security    6.x           OAuth2, JWT, MFA, CSRF,
session management

Auth Server     Spring             1.x           Standards-compliant
Authorization                    OAuth2/OIDC
Server

ORM             Spring Data JPA +  6.x           Type-safe queries,
Hibernate                        migrations

Reactive DB     Spring Data R2DBC  3.x           Non-blocking PostgreSQL
access for auth service

Build Tool      Maven / Gradle     3.9.x / 8.x   Dependency management,
reproducible builds

API Docs        SpringDoc OpenAPI  2.x           Auto-generated Swagger
docs from annotations

Validation      Jakarta Bean       3.x           Annotation-based
Validation                       validation (@Valid,
\@NotNull)

Mapping         MapStruct          1.6.x         Type-safe DTO/Entity
mapping at compile time

Utilities       Lombok             1.18.x        Reduce boilerplate
(getters, builders,
logging)
  --------------------------------------------------------------------------

**2.2 Service Architecture --- Java/Spring Mapping**

  ------------------------------------------------------------------------
**Service**     **Spring        **Key Spring Modules** **Scale
Stack**                                Strategy**
  --------------- --------------- ---------------------- -----------------
Auth Service    Spring Boot +   Spring Security,       Horizontal,
MVC +           Spring Authorization   stateless JWT,
VirtualThreads  Server, JPA            virtual threads

Registration    Spring Boot +   Spring Data JPA, Bean  Horizontal,
Service         MVC +           Validation, Events     stateless
VirtualThreads

Session Service Spring Boot +   Spring Session         Horizontal,
MVC +           (Redis), JPA           low-latency,
VirtualThreads                         virtual threads

Password        Spring Boot +   Spring Security        Horizontal,
Service         MVC             Crypto, Bean           stateless
Validation

Device Service  Spring Boot +   Spring Data JPA,       Horizontal,
MVC             Spring Cache           stateless

Security        Spring Boot +   Spring Security,       Horizontal,
Service         WebFlux         Reactive Redis         real-time risk

Notification    Spring Boot +   Spring Mail, Spring    Queue-based,
Service         MVC             Events, Kafka Listener async

Audit Service   Spring Boot +   Spring Data JPA, Kafka Event-driven,
MVC             Listener, Scheduling   async
  ------------------------------------------------------------------------

**2.3 Spring Security Configuration**

Spring Security 6.x provides native support for all authentication flows
required by this system. Key configuration areas include:

  -----------------------------------------------------------------------------------------
**Feature**        **Spring Security Component**     **Configuration**
  ------------------ --------------------------------- ------------------------------------
JWT Authentication BearerTokenAuthenticationFilter   RS256/ES256 with JWK endpoint

OAuth2 / OIDC      Spring Authorization Server       Standards-compliant, custom token
claims

MFA / TOTP         Custom AuthenticationProvider     speakeasy-equivalent via
google-authenticator-java

Password Encoding  PasswordEncoder (BCrypt/Argon2)   BCryptPasswordEncoder(strength=12)

Rate Limiting      Custom Filter + Redis             Token bucket via Bucket4j + Redis

CSRF Protection    CsrfFilter                        Cookie-based CSRF token for SPAs

Session Management SessionManagementFilter           Stateless JWT + Redis session
fallback

Account Lockout    Custom                            Failed attempt counter in Redis/DB
AuthenticationEventListener

Brute Force        Custom Filter                     IP-based + account-based lockout
Protection                                           logic
  -----------------------------------------------------------------------------------------

**2.4 Key Spring Libraries**

  -----------------------------------------------------------------------------------------------
**Library**                 **Purpose**           **Maven Artifact**
  --------------------------- --------------------- ---------------------------------------------
Spring Boot Starter         Core security         spring-boot-starter-security
Security                    framework

Spring Authorization Server OAuth2/OIDC server    spring-security-oauth2-authorization-server

Spring Boot Starter OAuth2  Social login (Google, spring-boot-starter-oauth2-client
Client                      Apple, Facebook)

Spring Boot Starter WebFlux Reactive non-blocking spring-boot-starter-webflux
REST

Spring Boot Starter Data    ORM for PostgreSQL    spring-boot-starter-data-jpa
JPA

Spring Data R2DBC           Reactive DB access    spring-boot-starter-data-r2dbc

Spring Session Data Redis   Distributed session   spring-session-data-redis
storage

Spring Boot Starter Cache   Caching abstraction   spring-boot-starter-cache

Spring Kafka                Event streaming       spring-kafka

Spring Boot Starter Mail    Email notifications   spring-boot-starter-mail

Spring Vault Core           HashiCorp Vault       spring-vault-core
integration

Bucket4j Spring Boot        Rate limiting         bucket4j-spring-boot-starter

google-authenticator-java   TOTP/MFA generation   com.warrenstrange:googleauth

JJWT                        JWT                   io.jsonwebtoken:jjwt-api
creation/validation

Springdoc OpenAPI           Auto Swagger docs     springdoc-openapi-starter-webmvc-ui

Micrometer + Prometheus     Metrics export        micrometer-registry-prometheus

Testcontainers              Integration testing   testcontainers
-----------------------------------------------------------------------------------------------

**3. API Layer**

  -----------------------------------------------------------------------
**Component**      **Technology**         **Purpose**
  ------------------ ---------------------- -----------------------------
API Gateway        Spring Cloud Gateway   Routing, rate limiting,
authentication, circuit
breaker

Load Balancer      AWS ALB + Spring Cloud Traffic distribution,
LoadBalancer           client-side load balancing

Service Mesh       Istio                  mTLS, observability, traffic
management

Inter-Service      Spring gRPC /          Reactive gRPC + declarative
Comm.              OpenFeign              REST clients

REST Contracts     OpenAPI 3.0 +          Auto-generated API
SpringDoc              documentation

Service Discovery  Spring Cloud Netflix   Dynamic service registration
Eureka / AWS Cloud Map

Config Management  Spring Cloud Config    Centralized configuration
Server                 with Git backend

Circuit Breaker    Spring Cloud Circuit   Fault tolerance, fallback
Breaker (Resilience4j) logic
  -----------------------------------------------------------------------

**3.1 Spring Cloud Gateway Configuration**

Spring Cloud Gateway replaces Kong Gateway and provides reactive routing
with built-in Spring Security integration. Key features include
predicates-based routing, global filters for authentication/rate
limiting, and circuit breaker integration via Resilience4j.

  -----------------------------------------------------------------------------------------
**Gateway          **Implementation**                       **Spring Component**
Feature**
  ------------------ ---------------------------------------- -----------------------------
JWT Validation     Global AuthFilter bean                   Spring Security + JJWT

Rate Limiting      RequestRateLimiterGatewayFilterFactory   Bucket4j + Redis

Circuit Breaker    SpringCloudCircuitBreakerFilterFactory   Resilience4j

Request Logging    GlobalFilter + MDC                       Logback + Sleuth TraceId

API Versioning     Path predicates (/v1/, /v2/)             RouteLocatorBuilder

CORS               CorsWebFilter                            Spring WebFlux CORS config
-----------------------------------------------------------------------------------------

**4. Security Infrastructure**

**4.1 Cryptographic Standards**

  --------------------------------------------------------------------------------
**Function**     **Algorithm**          **Key Size** **Spring/Java Library**
  ---------------- ---------------------- ------------ ---------------------------
Password Hashing BCrypt                 Cost 12      BCryptPasswordEncoder
(Spring Security)

Password Hashing Argon2id               Memory 64MB  Argon2PasswordEncoder
(Alt)                                                (Spring Security 6)

Token Signing    RS256                  2048-bit RSA Spring Authorization
Server + Nimbus JOSE

Token Signing    ES256                  P-256 curve  Spring Authorization
(Alt)                                                Server + Nimbus JOSE

Data Encryption  AES-256-GCM            256-bit      Java Cipher API + AWS KMS

Transport        TLS 1.3                \-           Spring Boot SSL
auto-config + ACM

OTP Generation   TOTP (SHA-1)           6 digits     google-authenticator-java
(com.warrenstrange)

Key Derivation   PBKDF2WithHmacSHA256   256-bit      Java SecretKeyFactory
--------------------------------------------------------------------------------

**4.2 Spring Security Controls**

  -----------------------------------------------------------------------
**Control**        **Implementation**    **Spring Component**
  ------------------ --------------------- ------------------------------
Authentication     Multi-provider auth   AuthenticationManager +
chain                 AuthenticationProvider

Authorization      Method security + URL \@PreAuthorize,
rules                 SecurityFilterChain

WAF                OWASP Core Rule Set   AWS WAF / Cloudflare
(external)

CSRF Protection    Cookie CSRF token     CsrfFilter with
CookieCsrfTokenRepository

XSS Prevention     Content Security      Spring Security headers config
Policy

Rate Limiting      Token bucket per      Bucket4j + Redis +
IP/user               GatewayFilter

Bot Detection      reCAPTCHA v3          Custom Spring Filter + Google
validation            API

Secrets Management HashiCorp Vault       Spring Vault
(spring-vault-core)

Key Management     AWS KMS               AWS SDK v2 + Spring \@Value
injection
  -----------------------------------------------------------------------

**5. Data Layer**

**5.1 Primary Database**

  -----------------------------------------------------------------------
**Attribute**      **Configuration**     **Spring Integration**
  ------------------ --------------------- ------------------------------
Engine             Aurora PostgreSQL     Spring Data JPA + Hibernate 6
16.x

Concurrency        Virtual Threads       HikariCP pool with virtual
model              (Java 21 Loom)        thread executor — blocking
I/O non-problematic

Connection Pooling HikariCP             Auto-configured by Spring Boot

Migrations         Flyway                spring-flyway-core (auto-run
on startup)

Auditing           Spring Data Auditing  \@CreatedDate,
\@LastModifiedDate,
\@CreatedBy

Multi-tenancy      Schema-per-tenant     Spring Data + Hibernate
(future)              multi-tenancy

Read Replicas      3+ Aurora replicas    Spring
AbstractRoutingDataSource
  -----------------------------------------------------------------------

**5.2 Caching (Redis + Spring Cache)**

  ------------------------------------------------------------------------------
**Data Type**    **TTL**     **Spring Cache Key**        **Implementation**
  ---------------- ----------- --------------------------- ---------------------
Sessions         30 min - 30 spring:session:{token}      Spring Session Data
days                                    Redis

Access Tokens    15 min      token:validation:{jti}      \@Cacheable + Redis

OTP Codes        5 min       otp:{customerId}            Spring Data Redis
(ValueOperations)

Rate Limit       1-60 min    ratelimit:{ip}:{endpoint}   Bucket4j + Redis
Counters

Device           1 hour      device:{fingerprint}        \@Cacheable
Fingerprints

User Profile     5 min       profile:{customerId}        \@Cacheable +
Cache                                                    CacheEvict

OAuth State      10 min      oauth:state:{stateId}       Spring Data Redis
------------------------------------------------------------------------------

**5.3 Spring Data Configuration**

  -------------------------------------------------------------------------------------------
**Dependency**                            **Purpose**           **Notes**
  ----------------------------------------- --------------------- ---------------------------
spring-boot-starter-data-jpa              Primary ORM (all      Hibernate 6, Jakarta
services)             Persistence; used with
virtual threads

flyway-core                               Schema migration      Auto-runs on Spring Boot
startup

spring-boot-starter-data-redis            Redis client          Lettuce driver (default);
sync ops with virtual
threads

spring-session-data-redis                 Distributed HTTP      Integrates with Spring
sessions              Security
  -------------------------------------------------------------------------------------------

**6. Messaging & Event Streaming**

**6.1 Spring Kafka Integration**

Apache Kafka (Amazon MSK) integration via Spring Kafka provides
annotation-driven consumer/producer configuration. Spring Kafka\'s
\@KafkaListener enables type-safe event consumption with error handling
and retry policies via DefaultErrorHandler.

  ---------------------------------------------------------------------------------
**Component**      **Technology**                  **Spring Dependency**
  ------------------ ------------------------------- ------------------------------
Kafka Producer     KafkaTemplate\<String, Object\> spring-kafka

Kafka Consumer     \@KafkaListener +               spring-kafka
\@RetryableTopic

Serialization      JSON via Jackson                JsonSerializer /
JsonDeserializer

Error Handling     DefaultErrorHandler + BackOff   spring-kafka

Dead Letter        DeadLetterPublishingRecoverer   spring-kafka

Transactions       KafkaTransactionManager         spring-kafka (exactly-once)

SQS Integration    Spring Cloud AWS SQS            spring-cloud-aws-starter-sqs
---------------------------------------------------------------------------------

**6.2 Kafka Topics**

  ------------------------------------------------------------------------------------------
**Topic**                  **Partitions**   **Purpose**        **Spring Listener Class**
  -------------------------- ---------------- ------------------ ---------------------------
auth.login.events          12               Login events       LoginEventConsumer

auth.registration.events   6                Registration       RegistrationEventConsumer
events

auth.password.events       6                Password changes   PasswordEventConsumer

auth.session.events        12               Session lifecycle  SessionEventConsumer

auth.security.events       6                Security alerts    SecurityEventConsumer

auth.audit.events          12               Audit trail        AuditEventConsumer

notifications.email        6                Email delivery     EmailNotificationConsumer

notifications.sms          6                SMS delivery       SmsNotificationConsumer
------------------------------------------------------------------------------------------

**7. Observability Stack**

**7.1 Spring Boot Actuator + Micrometer**

Spring Boot Actuator provides production-ready endpoints
(/actuator/health, /actuator/metrics, /actuator/prometheus). Micrometer
acts as the instrumentation facade, exporting metrics to Prometheus with
pre-built Spring Security and Spring MVC auto-instrumentation.

  ------------------------------------------------------------------------
**Component**    **Technology**        **Spring Integration**
  ---------------- --------------------- ---------------------------------
Metrics          Micrometer +          spring-boot-starter-actuator +
Collection       Prometheus            micrometer-registry-prometheus

Distributed      Micrometer Tracing +  spring-boot-starter-actuator +
Tracing          Zipkin/Jaeger         micrometer-tracing-bridge-otel

Log Correlation  MDC + Logback         spring-boot-starter-logging
(auto-configured)

Health Checks    Spring Boot Actuator  /actuator/health with DB, Redis,
Kafka indicators

Metrics          Grafana               Prometheus data source
Visualization

Log Aggregation  Fluent Bit +          JSON log format via Logback
Elasticsearch

Alerting         Alertmanager          Prometheus alert rules
------------------------------------------------------------------------

**7.2 Key Metrics (Spring Auto-instrumented)**

  -------------------------------------------------------------------------------------------------
**Metric**                                **Type**          **Alert         **Source**
Threshold**
  ----------------------------------------- ----------------- --------------- ---------------------
http.server.requests (auth)               Timer/Histogram   p99 \> 2s       Spring MVC / WebFlux
auto

spring.security.authentications.success   Counter           \-              Spring Security
Micrometer

spring.security.authentications.failure   Counter           Rate \> 100/min Spring Security
Micrometer

hikaricp.connections.active               Gauge             \> 80% pool     HikariCP Micrometer

redis.commands.duration                   Timer             p99 \> 50ms     Lettuce Micrometer

spring.kafka.consumer.lag                 Gauge             \> 10K          Spring Kafka
Micrometer

jvm.memory.used                           Gauge             \> 80% heap     JVM Micrometer (auto)

jvm.threads.live                          Gauge             \> 500 platform JVM Micrometer (auto)
threads
  -------------------------------------------------------------------------------------------------

**8. Frontend Technology Stack (Unchanged)**

Frontend technology remains unchanged from the original specification,
as it is framework-agnostic with respect to backend language.

**8.1 Web Application**

  -----------------------------------------------------------------------
**Component**      **Technology**             **Version**
  ------------------ -------------------------- -------------------------
Framework          React                      18.x

Language           TypeScript                 5.x

State Management   Zustand / Redux Toolkit    Latest

HTTP Client        Axios + TanStack Query     Latest

UI Components      Radix UI + Tailwind CSS    Latest

Build Tool         Vite                       5.x

Testing            Vitest + Testing Library   Latest
-----------------------------------------------------------------------

**8.2 Mobile Applications**

  ------------------------------------------------------------------------------
**Platform**     **Language**   **Framework**   **Key Libraries**
  ---------------- -------------- --------------- ------------------------------
iOS              Swift 5.9+     SwiftUI         Alamofire, KeychainSwift,
SecureEnclave (token storage)

Android          Kotlin 1.9+    Jetpack Compose Retrofit,
EncryptedSharedPreferences,
Credential Manager (passkeys — future)

Cross-Platform   Dart           Flutter 3.x     Single codebase alternative
(Alt)
  ------------------------------------------------------------------------------

**9. Infrastructure & DevOps**

**9.1 Container & Orchestration**

  -----------------------------------------------------------------------
**Component**      **Technology**         **Notes**
  ------------------ ---------------------- -----------------------------
Containerization   Docker                 Standard Dockerfile; portable
                                        across all CI/CD systems

Base Image         Eclipse Temurin 21     Minimal attack surface, Java
(distroless)           21 LTS

Orchestration      Kubernetes (EKS) 1.29+ Managed control plane,
Karpenter autoscaling

Service Mesh       Istio                  mTLS, circuit breaking,
observability

IaC                Terraform + Helm       Infrastructure provisioning +
K8s deployments

GitOps             ArgoCD                 Continuous deployment from
Git

Secrets            HashiCorp Vault +      spring-vault-core
Spring Vault           auto-injects secrets

Config             Spring Cloud Config    Git-backed centralized
Server                 configuration
  -----------------------------------------------------------------------

**9.2 CI/CD Pipeline (Java-specific)**

  -----------------------------------------------------------------------
**Stage**          **Tool**              **Java-Specific Action**
  ------------------ --------------------- ------------------------------
Source Control     GitHub Enterprise     Branch protection, PR reviews

Build              GitHub Actions +      mvn clean package -DskipTests
Maven/Gradle

Unit Tests         JUnit 5 + Mockito     mvn test with Surefire plugin

Integration Tests  Testcontainers +      mvn verify with Failsafe
Spring Test           plugin

Code Quality       SonarQube +           sonar:sonar goal, PMD/SpotBugs
Checkstyle

SAST               SpotBugs + OWASP      Java bytecode analysis
Dependency Check

Container Build    Docker                docker build via Dockerfile

Container Scan     Trivy                 Scan JVM image layers

DAST               OWASP ZAP             Against staging environment

Deployment         ArgoCD                GitOps sync from ECR digest

Feature Flags      LaunchDarkly Java SDK Progressive rollout in Spring
beans
  -----------------------------------------------------------------------

**10. Third-Party Integrations**

  -----------------------------------------------------------------------
**Category**       **Provider**       **Spring Integration**
  ------------------ ------------------ ---------------------------------
Email Delivery     Amazon SES         Spring Cloud AWS SES +
(Primary)                             JavaMailSender

Email Delivery     SendGrid           sendgrid-java SDK + Spring
(Fallback)                            \@Service

SMS Delivery       Twilio             twilio-java SDK + Spring
(Primary)                             \@Service

SMS Delivery       Amazon SNS         Spring Cloud AWS SNS
(Fallback)

Push Notifications APNs               pushy or notnoop/java-apns
(iOS)                                 library

Push Notifications FCM                firebase-admin Java SDK
(Android/Web)

OAuth2 Provider    Google OAuth2 /    Spring Security OAuth2 Client
(Google)           OIDC               (auto-config)

OAuth2 Provider    Facebook OAuth2    Spring Security OAuth2 Client
(Facebook)

CAPTCHA            reCAPTCHA v3       Custom Spring Filter +
RestTemplate

IP Intelligence    MaxMind GeoIP2     geoip2 Java SDK + Spring
\@Component

Breach Detection   Have I Been Pwned  WebClient (reactive) + Spring
API                Cache

Device             FingerprintJS Pro  Server-side API via WebClient
Intelligence
  -----------------------------------------------------------------------

**11. Development Tools**

  ---------------------------------------------------------------------------
**Tool**           **Purpose**            **Java-Specific Notes**
  ------------------ ---------------------- ---------------------------------
IDE                IntelliJ IDEA Ultimate Best-in-class Spring Boot
support, Spring Initializr

API Testing        Postman / IntelliJ     Built-in .http file support in
HTTP Client            IntelliJ

Local Development  Docker Compose +       Spring Boot 3.1+ Docker Compose
Testcontainers         support

Database Client    DBeaver / TablePlus    PostgreSQL, schema visualization

Redis Client       RedisInsight           Visual Redis data explorer

Build Tool         Maven 3.9.x / Gradle   Both supported; Maven recommended
8.x                    for Spring Boot

Java Version       SDKMAN!                Manage Java 21 + multiple JDK
Manager                                   versions

Code Formatting    google-java-format +   Enforced via Maven plugin +
Checkstyle             pre-commit

Static Analysis    SpotBugs + PMD +       IntelliJ plugin + CI integration
SonarLint

Dependency Check   OWASP Dependency Check CVE scanning of Java dependencies
Maven Plugin

Performance        JDK Mission Control +  JVM-level CPU/memory profiling
Profiling          async-profiler
  ---------------------------------------------------------------------------

**12. Technology Decision Matrix**

**12.1 Backend Framework Decision --- Updated**

  ----------------------------------------------------------------------------------
**Criteria**      **Weight**   **Spring Boot     **Node.js/NestJS**   **Go/Gin**
(Java 21)**
  ----------------- ------------ ----------------- -------------------- ------------
Performance       20%          9 (virtual        7                    10
threads)

Scalability       20%          9                 8                    9

Security          25%          10 (Spring        7                    6
Ecosystem                      Security)

Developer         15%          9 (Spring Boot    9                    6
Productivity                   auto-config)

Enterprise        10%          10                8                    5
Ecosystem

Talent            10%          9                 9                    6
Availability

Weighted Score    100%         9.35              7.90                 7.45
----------------------------------------------------------------------------------

Recommendation: Java 21 + Spring Boot 3.x as the unified backend
framework. Virtual threads (Project Loom) eliminate the performance gap
previously addressed by Go for high-concurrency services, while Spring
Security\'s depth provides significant advantages for authentication
workloads.

**13. Cost Estimation**

**13.1 Monthly Infrastructure Cost (Production) --- Updated**

  -----------------------------------------------------------------------
**Component**              **Configuration**      **Monthly Cost
(USD)**
  -------------------------- ---------------------- ---------------------
Compute (EKS Worker Nodes) 20x c6i.2xlarge + 10x  \$6,000
Spot

Database (Aurora           Primary + 3 Read       \$3,500
PostgreSQL)                Replicas + 2TB

Cache (ElastiCache Redis)  6x cache.r6g.xlarge    \$2,400
Cluster

Messaging (MSK Kafka)      6x kafka.m5.2xlarge    \$3,600

Search (OpenSearch)        6x r6g.2xlarge + 12TB  \$6,240

Networking (ALB + CDN +    CloudFront 50TB + Data \$5,200
Transfer)                  10TB

Security (WAF + KMS +      10M requests + 100     \$170
Secrets)                   secrets

Observability (CloudWatch) Logs + Metrics +       \$600
Traces

Third-Party (SES +         Email + SMS + Device   \$5,650
Twilio + FJS)              ID

Spring Cloud Config /      HashiCorp Vault        \$300
Vault                      cluster (3 nodes)

Total                                             \~\$33,660/month
-----------------------------------------------------------------------

Note: Java/Spring infrastructure costs are equivalent to the previous
Node.js/Go stack. JVM memory overhead is offset by reduced service count
(Spring Boot consolidates features previously requiring separate Node.js
packages).

**14. Implementation Roadmap**

**14.1 Phase 1: Foundation (Weeks 1-4)**

  -----------------------------------------------------------------------
**Week**    **Deliverables**
  ----------- -----------------------------------------------------------
1           Infrastructure setup (Terraform + EKS), Spring Cloud Config
Server, Vault integration

2           Aurora PostgreSQL + Flyway migrations, Redis cluster,
Spring Data setup

3           Spring Cloud Gateway, Istio service mesh,
Prometheus/Grafana with Spring Actuator

4           CI/CD pipeline (GitHub Actions + Docker + ArgoCD), SonarQube,
Testcontainers setup
  -----------------------------------------------------------------------

**14.2 Phase 2: Core Services (Weeks 5-10)**

  -----------------------------------------------------------------------
**Week**    **Deliverables**
  ----------- -----------------------------------------------------------
5-6         Auth Service (Spring Security + Spring Authorization
Server, JWT, MFA, OAuth2 Social Login)

7           Session Service (Spring Session Data Redis, reactive
WebFlux)

8           Registration Service (Spring MVC, Bean Validation, Flyway
schema)

9           Password Service (Argon2id/BCrypt, Spring Security Crypto,
breach detection)

10          Device Service + Security Service (risk engine, Bucket4j
rate limiting, lockout logic)
  -----------------------------------------------------------------------

**14.3 Phase 3: Extended Features (Weeks 11-14)**

  -----------------------------------------------------------------------
**Week**    **Deliverables**
  ----------- -----------------------------------------------------------
11          Notification Service (Spring Kafka consumer,
JavaMailSender, Twilio, FCM)

12          Audit Service (Kafka consumer, Spring Data JPA, OpenSearch
indexing)

13          Admin dashboard, Grafana dashboards, Spring Actuator custom
health indicators

14          Load testing (Gatling/k6), performance tuning (JVM GC,
HikariCP, R2DBC pool)
  -----------------------------------------------------------------------

**14.4 Phase 4: Launch Preparation (Weeks 15-16)**

  -----------------------------------------------------------------------
**Week**    **Deliverables**
  ----------- -----------------------------------------------------------
15          Penetration testing (OWASP ZAP + manual), Spring Security
hardening review, SAST cleanup

16          Documentation (SpringDoc OpenAPI), runbooks, JVM tuning
guide, go-live
  -----------------------------------------------------------------------

**Appendix A: Java/Spring Version Matrix**

  ------------------------------------------------------------------------
**Technology**         **Version**     **Release       **EOL Date**
Date**
  ---------------------- --------------- --------------- -----------------
Java (OpenJDK /        21 LTS          Sept 2023       Sept 2031
Temurin)

Spring Boot            3.3.x           May 2024        Nov 2025 (OSS) /
longer commercial

Spring Framework       6.1.x           Nov 2023        Dec 2025 (OSS)

Spring Security        6.3.x           May 2024        Aligned with
Spring Boot 3.3

Spring Authorization   1.3.x           May 2024        Aligned with
Server                                                 Spring Boot

Spring Cloud           2023.0.x        Jan 2024        Dec 2025
(Leyton)

Hibernate ORM          6.5.x           May 2024        Long-term

Flyway                 10.x            2024            Long-term

PostgreSQL Driver      1.0.x           2023            Long-term
(R2DBC)
  ------------------------------------------------------------------------

**Appendix B: Security Compliance --- Spring Mappings**

  ---------------------------------------------------------------------------
**Control**     **GDPR**   **SOC 2** **PCI     **Spring Implementation**
DSS**
  --------------- ---------- --------- --------- ----------------------------
Encryption at   ✓          ✓         ✓         AWS KMS + Spring Vault
Rest                                           property encryption

Encryption in   ✓          ✓         ✓         Spring Boot TLS
Transit                                        auto-config + Istio mTLS

Access Logging  ✓          ✓         ✓         Spring Actuator
AuditEventRepository + Kafka

Data Retention  ✓          ✓         ✓         Spring Scheduled
(@Scheduled) automated
deletion — audit log
retained 6 months only

Right to        ✓          \-        \-        Spring Data JPA soft/hard
Erasure                                        delete + Kafka event

Consent         ✓          \-        \-        Spring MVC endpoint + DB
Management                                     consent flag

Vuln Scanning   \-         ✓         ✓         OWASP Dependency Check +
Trivy + SpotBugs

Penetration     \-         ✓         ✓         Annual OWASP ZAP + manual
Testing                                        assessment
  ---------------------------------------------------------------------------