# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Spring Boot 3.4.2 REST API built on Java 21 and Maven. Uses Spring Web, Spring Data JPA, and PostgreSQL.

## Build & Run Commands

```bash
# Compile
mvn compile

# Run tests (uses H2 in-memory — no PostgreSQL needed)
mvn test

# Run a single test class
mvn test -Dtest=ECommerceApplicationTests

# Start the application (requires PostgreSQL env vars — see below)
mvn spring-boot:run

# Build executable JAR
mvn clean package

# Run the JAR
java -jar target/ECommerce-1.0-SNAPSHOT.jar
```

## Environment Variables (for running locally)

| Variable    | Default        | Description          |
|-------------|----------------|----------------------|
| `DB_HOST`   | `localhost`    | PostgreSQL host      |
| `DB_PORT`   | `5432`         | PostgreSQL port      |
| `DB_NAME`   | `ecommerce_db` | Database name        |
| `DB_USER`   | `postgres`     | Database username    |
| `DB_PASSWORD` | *(empty)*    | Database password    |

## Architecture

```
org.example/
├── ECommerceApplication.java   # @SpringBootApplication entry point
├── controller/                 # @RestController — HTTP layer only, delegates to services
├── service/                    # @Service — business logic, transactional
├── repository/                 # @Repository — Spring Data JPA interfaces
├── model/                      # @Entity classes and DTOs
└── config/                     # @Configuration beans (security, CORS, etc.)
```

**Layering rule:** Controllers call services; services call repositories. Controllers never access repositories directly.

## Key Endpoints

| Method | Path          | Description              |
|--------|---------------|--------------------------|
| GET    | `/api/health` | Liveness check — returns `{ "status": "UP", ... }` |

## Testing

Tests use `@ActiveProfiles("test")` which activates `src/test/resources/application-test.properties`. This profile swaps PostgreSQL for H2 (in-memory, PostgreSQL-mode), so tests run without a live database.

- `@SpringBootTest` — full context load tests
- `@WebMvcTest` — controller-layer slice tests (use when adding new controllers)