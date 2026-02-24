# End-to-End Setup Guide
## ECommerce CIAM Platform — From Zero to Running Server

> This guide takes you from a fresh machine with nothing installed to a fully running server — locally first, then cloud-deployed.
> Every command, config value, and expected output is included.

---

## Table of Contents

1. [Prerequisites — Tool Installation](#1-prerequisites--tool-installation)
2. [Clone and Verify the Repository](#2-clone-and-verify-the-repository)
3. [Generate Dev RSA Keys](#3-generate-dev-rsa-keys)
4. [Local Infrastructure — Docker Compose](#4-local-infrastructure--docker-compose)
5. [Verify Infrastructure Health](#5-verify-infrastructure-health)
6. [Build the Application](#6-build-the-application)
7. [Run Tests](#7-run-tests)
8. [Start the Application (Local Dev)](#8-start-the-application-local-dev)
9. [Verify the Running Server](#9-verify-the-running-server)
10. [Run with Docker (Containerised)](#10-run-with-docker-containerised)
11. [AWS Account & CLI Setup](#11-aws-account--cli-setup)
12. [Terraform State Bootstrap (One-Time)](#12-terraform-state-bootstrap-one-time)
13. [Provision Dev Infrastructure via Terraform](#13-provision-dev-infrastructure-via-terraform)
14. [Connect kubectl to EKS](#14-connect-kubectl-to-eks)
15. [Deploy to Kubernetes (Dev)](#15-deploy-to-kubernetes-dev)
16. [Set Up ArgoCD GitOps](#16-set-up-argocd-gitops)
17. [CI/CD — GitHub Actions Setup](#17-cicd--github-actions-setup)
18. [Monitoring Stack Setup](#18-monitoring-stack-setup)
19. [Staging & Production Deployment](#19-staging--production-deployment)
20. [Complete Verification Checklist](#20-complete-verification-checklist)
21. [Environment Variable Reference](#21-environment-variable-reference)
22. [Troubleshooting](#22-troubleshooting)

---

## 1. Prerequisites — Tool Installation

Install every tool below before proceeding. Version minimums are enforced by the project.

### 1.1 Java 21 LTS

The application requires Java 21 (Virtual Threads / Project Loom).

**macOS / Linux (via SDKMAN — recommended):**
```bash
# Install SDKMAN
curl -s "https://get.sdkman.io" | bash
source "$HOME/.sdkman/bin/sdkman-init.sh"

# Install Java 21 (Eclipse Temurin — same as Docker image)
sdk install java 21.0.4-tem
sdk use java 21.0.4-tem
sdk default java 21.0.4-tem
```

**Windows:**
```powershell
# Download Eclipse Temurin 21 from https://adoptium.net/
# Or via winget:
winget install EclipseAdoptium.Temurin.21.JDK
```

**Verify:**
```bash
java -version
# Expected: openjdk version "21.x.x" ...
javac -version
# Expected: javac 21.x.x
```

---

### 1.2 Maven 3.9+

```bash
# macOS / Linux via SDKMAN
sdk install maven 3.9.6

# macOS via Homebrew
brew install maven

# Windows via winget
winget install Apache.Maven

# Or download from https://maven.apache.org/download.cgi
# and add to PATH manually
```

**Verify:**
```bash
mvn -version
# Expected: Apache Maven 3.9.x ... Java version: 21
```

---

### 1.3 Docker Desktop (Docker + Docker Compose)

Docker runs all local infrastructure (PostgreSQL, Redis, Kafka, OpenSearch).

**macOS / Windows:**
- Download from https://www.docker.com/products/docker-desktop
- Install and start Docker Desktop

**Linux:**
```bash
# Ubuntu/Debian
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER
newgrp docker

# Install Docker Compose plugin
sudo apt-get install docker-compose-plugin
```

**Verify:**
```bash
docker version
# Expected: Docker Engine 24+

docker compose version
# Expected: Docker Compose version v2.x
```

> **Important:** Make sure Docker Desktop is **running** (system tray icon visible) before proceeding to Step 4.

---

### 1.4 Git

```bash
# macOS
brew install git

# Windows
winget install Git.Git

# Ubuntu/Debian
sudo apt-get install git
```

**Verify:**
```bash
git --version
# Expected: git version 2.x
```

---

### 1.5 OpenSSL (for RSA key generation)

```bash
# macOS — already installed, or:
brew install openssl

# Windows (via Git Bash — already included) or:
winget install ShiningLight.OpenSSL

# Linux
sudo apt-get install openssl
```

**Verify:**
```bash
openssl version
# Expected: OpenSSL 3.x.x
```

---

### 1.6 AWS CLI v2 (required for cloud steps — skip if local-only)

```bash
# macOS
brew install awscli

# Linux
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip && sudo ./aws/install

# Windows
winget install Amazon.AWSCLI
```

**Verify:**
```bash
aws --version
# Expected: aws-cli/2.x.x Python/3.x
```

---

### 1.7 Terraform 1.7+ (required for cloud steps — skip if local-only)

```bash
# macOS via Homebrew
brew tap hashicorp/tap
brew install hashicorp/tap/terraform

# Linux
wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install terraform

# Windows via winget
winget install Hashicorp.Terraform
```

**Verify:**
```bash
terraform version
# Expected: Terraform v1.7.x
```

---

### 1.8 kubectl (required for cloud steps — skip if local-only)

```bash
# macOS
brew install kubectl

# Linux
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# Windows
winget install Kubernetes.kubectl
```

**Verify:**
```bash
kubectl version --client
# Expected: Client Version: v1.x
```

---

### 1.9 Kustomize (required for K8s deployment)

```bash
# macOS
brew install kustomize

# Linux / Windows
# Download from https://kubectl.docs.kubernetes.io/installation/kustomize/
curl -s "https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh" | bash
sudo mv kustomize /usr/local/bin/
```

**Verify:**
```bash
kustomize version
# Expected: v5.x.x
```

---

### 1.10 IDE (Optional but Recommended)

IntelliJ IDEA (Community or Ultimate):
- Download from https://www.jetbrains.com/idea/download/
- Install plugins: `Lombok`, `MapStruct Support`, `Docker`, `Kubernetes`

---

### Tool Version Summary

| Tool | Minimum Version | Check Command |
|---|---|---|
| Java | 21 LTS | `java -version` |
| Maven | 3.9 | `mvn -version` |
| Docker Engine | 24 | `docker version` |
| Docker Compose | v2.x | `docker compose version` |
| Git | 2.x | `git --version` |
| OpenSSL | 3.x | `openssl version` |
| AWS CLI | 2.x | `aws --version` |
| Terraform | 1.7 | `terraform version` |
| kubectl | 1.28+ | `kubectl version --client` |
| Kustomize | 5.x | `kustomize version` |

---

## 2. Clone and Verify the Repository

```bash
# Clone the repository
git clone <repository-url>
cd ECommerce

# Verify project structure
ls -la
```

**Expected structure:**
```
ECommerce/
├── src/
│   ├── main/
│   │   ├── java/org/example/
│   │   │   ├── ECommerceApplication.java
│   │   │   ├── shared/
│   │   │   ├── identity/
│   │   │   ├── profile/
│   │   │   ├── notification/
│   │   │   └── audit/
│   │   └── resources/
│   │       ├── application.yml
│   │       ├── application-dev.yml
│   │       ├── application-test.yml
│   │       ├── application-staging.yml
│   │       ├── application-prod.yml
│   │       ├── keys/             ← RSA keys go here
│   │       ├── db/migration/     ← Flyway SQL files
│   │       └── logback-spring.xml
│   └── test/
├── docker-compose.yml
├── Dockerfile
├── pom.xml
├── k8s/
├── terraform/
├── monitoring/
├── performance-tests/
└── docs/
```

---

## 3. Generate Dev RSA Keys

The application uses RS256 JWT signing. Dev keys are loaded from the classpath. **This step is required before the application can start.**

```bash
# Navigate to the keys directory
cd src/main/resources/keys

# Step 1: Generate a 2048-bit RSA private key
openssl genrsa -out dev-private-raw.pem 2048

# Step 2: Extract the public key
openssl rsa -in dev-private-raw.pem -pubout -out dev-public.pem

# Step 3: Convert private key to PKCS#8 format (required by Java's NimbusJWT)
openssl pkcs8 -topk8 -inform PEM -outform PEM -nocrypt \
    -in dev-private-raw.pem -out dev-private.pem

# Step 4: Clean up the raw key
rm dev-private-raw.pem

# Go back to project root
cd ../../../..
```

**Verify both files exist:**
```bash
ls src/main/resources/keys/
# Expected: dev-private.pem  dev-public.pem  README.md
```

**Verify the private key is PKCS#8 format (first line must say PRIVATE KEY, not RSA PRIVATE KEY):**
```bash
head -1 src/main/resources/keys/dev-private.pem
# Expected: -----BEGIN PRIVATE KEY-----
```

> **Security note:** These keys are for local dev only. They are committed to the repository intentionally. In staging/prod, keys are managed by AWS KMS — the private key never touches the filesystem.

---

## 4. Local Infrastructure — Docker Compose

All local infrastructure (PostgreSQL, Redis, Kafka, OpenSearch) runs as Docker containers.

### 4.1 Start All Infrastructure

From the project root:

```bash
docker compose up -d
```

**Expected output:**
```
[+] Running 5/5
 ✔ Network ecommerce_default      Created
 ✔ Container ecommerce-postgres   Started
 ✔ Container ecommerce-redis      Started
 ✔ Container ecommerce-kafka      Started
 ✔ Container ecommerce-opensearch Started
```

### 4.2 What Gets Started

| Container | Image | Port | Purpose |
|---|---|---|---|
| `ecommerce-postgres` | `postgres:16-alpine` | `5432` | Primary database |
| `ecommerce-redis` | `redis:7-alpine` | `6379` | Session store + rate limiting |
| `ecommerce-kafka` | `apache/kafka:3.8.0` | `9092` | Event bus (KRaft — no ZooKeeper) |
| `ecommerce-opensearch` | `opensearchproject/opensearch:2.17.1` | `9200` | Login history search |

### 4.3 Default Credentials

| Service | Host | Port | Username | Password | Database |
|---|---|---|---|---|---|
| PostgreSQL | `localhost` | `5432` | `postgres` | `postgres` | `ecommerce_db` |
| Redis | `localhost` | `6379` | — | — | — |
| Kafka | `localhost` | `9092` | — | — | — |
| OpenSearch | `localhost` | `9200` | — | — | — |

---

## 5. Verify Infrastructure Health

Wait ~30 seconds after `docker compose up` for all services to initialise, then check:

### 5.1 Check All Containers Are Running

```bash
docker compose ps
```

**Expected (all containers should show `healthy` or `running`):**
```
NAME                    IMAGE                                    STATUS
ecommerce-kafka         apache/kafka:3.8.0                       Up (healthy)
ecommerce-opensearch    opensearchproject/opensearch:2.17.1      Up (healthy)
ecommerce-postgres      postgres:16-alpine                       Up (healthy)
ecommerce-redis         redis:7-alpine                           Up (healthy)
```

> If any container shows `starting` instead of `healthy`, wait 30 more seconds and run `docker compose ps` again.

### 5.2 Verify PostgreSQL

```bash
docker exec ecommerce-postgres pg_isready -U postgres
# Expected: /var/run/postgresql:5432 - accepting connections
```

### 5.3 Verify Redis

```bash
docker exec ecommerce-redis redis-cli ping
# Expected: PONG
```

### 5.4 Verify Kafka

```bash
docker exec ecommerce-kafka /opt/kafka/bin/kafka-broker-api-versions.sh \
    --bootstrap-server localhost:9092 2>/dev/null | head -3
# Expected: shows broker version info (3.8.x)
```

### 5.5 Verify OpenSearch

```bash
curl -s http://localhost:9200/_cluster/health | python3 -m json.tool
# Expected: "status": "green" or "yellow"
```

---

## 6. Build the Application

### 6.1 Resolve Dependencies

```bash
mvn dependency:resolve -q
```

**Expected:** `BUILD SUCCESS` (first run downloads ~500MB of dependencies — subsequent runs are cached)

### 6.2 Compile

```bash
mvn compile
```

**Expected output ends with:**
```
[INFO] ------------------------------------------------------------------------
[INFO] BUILD SUCCESS
[INFO] ------------------------------------------------------------------------
```

> **If compile fails:** Check that `java -version` shows Java 21. Maven must use Java 21 — not 17 or 11.

---

## 7. Run Tests

### 7.1 Unit Tests (No Docker Required)

Unit tests use H2 in-memory database (PostgreSQL-compatible mode). No infrastructure needed.

```bash
mvn test
```

**Expected:**
```
[INFO] Tests run: X, Failures: 0, Errors: 0, Skipped: 0
[INFO] BUILD SUCCESS
```

### 7.2 Architecture Tests Only

ArchUnit tests verify that the package dependency rules are not violated. Run these whenever you add new classes:

```bash
mvn test -Dtest=PackageBoundaryTest,CodingConventionTest
```

**Expected:**
```
[INFO] Tests run: 6, Failures: 0, Errors: 0, Skipped: 0
```

> If ArchUnit tests fail, it means a class was placed in the wrong package or a forbidden dependency was introduced. Read the failure message — it states exactly which class violated which rule.

### 7.3 Integration Tests (Requires Docker running)

Integration tests use Testcontainers — they spin up fresh PostgreSQL and Kafka containers automatically:

```bash
mvn verify -Pfailsafe
```

**Expected:**
```
[INFO] BUILD SUCCESS
```

---

## 8. Start the Application (Local Dev)

### 8.1 Environment Variables

The dev profile uses defaults for all values. No environment variables need to be set manually.

**What the `dev` profile uses:**

| Variable | Default Value | Set in |
|---|---|---|
| `DB_HOST` | `localhost` | `application-dev.yml` |
| `DB_PORT` | `5432` | `application-dev.yml` |
| `DB_NAME` | `ecommerce_db` | `application-dev.yml` |
| `DB_USER` | `postgres` | `application-dev.yml` |
| `DB_PASSWORD` | `postgres` | `application-dev.yml` |
| `REDIS_HOST` | `localhost` | `application.yml` |
| `REDIS_PORT` | `6379` | `application.yml` |
| `KAFKA_BOOTSTRAP_SERVERS` | `localhost:9092` | `application.yml` |
| JWT keys | `classpath:keys/dev-*.pem` | `application-dev.yml` |

### 8.2 Start with Maven (Recommended for Development)

Make sure Docker Compose infrastructure is running (Step 4), then:

```bash
mvn spring-boot:run -Dspring-boot.run.profiles=dev
```

### 8.3 What Happens at Startup

Watch the startup log — each phase should complete successfully:

```
  .   ____          _            __ _ _
 /\\ / ___'_ __ _ _(_)_ __  __ _ \ \ \ \
( ( )\___ | '_ | '_| | '_ \/ _` | \ \ \ \
 \\/  ___)| |_)| | | | | || (_| |  ) ) ) )
  '  |____| .__|_| |_|_| |_\__, | / / / /
 =========|_|==============|___/=/_/_/_/
 :: Spring Boot ::                (v3.4.2)

... Starting ECommerceApplication ...
... Virtual threads enabled        ← Java 21 Loom
... HikariPool-1 - Starting...
... HikariPool-1 - Start completed ← PostgreSQL connected
... Flyway Community Edition ...
... Current version of schema ...
... Migrating schema ... to version 1 - create schemas
... Migrating schema ... to version 2 - create identity tables
... Migrating schema ... to version 3 - create audit tables
... Migrating schema ... to version 4 - create indexes
... Successfully applied 4 migrations ← DB schema created
... Started ECommerceApplication in X.XXX seconds
```

**Expected final line:**
```
Started ECommerceApplication in X.XXX seconds (process running for X.XXX)
```

### 8.4 Application is Ready When:

Port `8080` is listening and the first request to `/actuator/health` returns UP.

---

## 9. Verify the Running Server

Run each of these in a **new terminal** while the application is running.

### 9.1 Health Check (most important)

```bash
curl -s http://localhost:8080/actuator/health | python3 -m json.tool
```

**Expected:**
```json
{
  "status": "UP",
  "components": {
    "db": {
      "status": "UP",
      "details": { "database": "PostgreSQL", "validationQuery": "isValid()" }
    },
    "redis": { "status": "UP" },
    "diskSpace": { "status": "UP" },
    "ping": { "status": "UP" }
  }
}
```

> If `db` shows `DOWN`, PostgreSQL is not reachable. Verify Docker is running and check Step 5.2.
> If `redis` shows `DOWN`, Redis is not reachable. Verify Docker is running and check Step 5.3.

### 9.2 Liveness Probe

```bash
curl -s http://localhost:8080/actuator/health/liveness
# Expected: {"status":"UP"}
```

### 9.3 Readiness Probe

```bash
curl -s http://localhost:8080/actuator/health/readiness
# Expected: {"status":"UP"}
```

### 9.4 Swagger UI

Open in browser: http://localhost:8080/swagger-ui.html

**Expected:** Swagger UI page showing API groups: `identity`, `profile`, `audit`, `actuator`

Or verify via curl:
```bash
curl -o /dev/null -s -w "%{http_code}" http://localhost:8080/swagger-ui.html
# Expected: 200
```

### 9.5 OpenAPI Spec

```bash
curl -s http://localhost:8080/v3/api-docs | python3 -m json.tool | head -10
# Expected: JSON with "openapi": "3.0.x", "info": { "title": ... }
```

### 9.6 Prometheus Metrics

```bash
curl -s http://localhost:8080/actuator/prometheus | head -20
# Expected: # HELP jvm_memory_used_bytes ...
#           # TYPE jvm_memory_used_bytes gauge
#           jvm_memory_used_bytes{...} ...
```

### 9.7 Application Info

```bash
curl -s http://localhost:8080/actuator/info | python3 -m json.tool
# Expected: {"app": {"name": "ecommerce-ciam", ...}}
```

### 9.8 Verify Flyway Ran Correctly (Database Check)

```bash
docker exec ecommerce-postgres psql -U postgres -d ecommerce_db -c \
    "\dn"
# Expected: identity | postgres
#           audit    | postgres
```

```bash
docker exec ecommerce-postgres psql -U postgres -d ecommerce_db -c \
    "\dt identity.*"
# Expected:
#  identity | consent          | table | postgres
#  identity | customer         | table | postgres
#  identity | device           | table | postgres
#  identity | mfa_secret       | table | postgres
#  identity | password_history | table | postgres
#  identity | social_link      | table | postgres
```

### 9.9 Verify Redis Key Namespace

```bash
docker exec ecommerce-redis redis-cli keys "ecommerce:*"
# Expected: (empty list) — no keys yet, which is correct at startup
```

---

## 10. Run with Docker (Containerised)

Build and run the application as a Docker container (mirrors production deployment).

### 10.1 Build the Docker Image

```bash
docker build -t ecommerce-ciam:local .
```

**Expected output (3-stage build):**
```
[1/3] FROM eclipse-temurin:21-jdk AS build
...
[2/3] FROM eclipse-temurin:21-jdk AS extract
...
[3/3] FROM eclipse-temurin:21-jre
...
 => exporting to image
 => => naming to docker.io/library/ecommerce-ciam:local
```

Build time: ~3-5 minutes on first run (downloads base images), ~30s on subsequent runs (Maven cache).

### 10.2 Run the Container

The application container needs to reach the infrastructure containers. Use `host.docker.internal` to reach `localhost` from inside Docker:

```bash
docker run -d \
  --name ecommerce-app \
  -p 8080:8080 \
  -e SPRING_PROFILES_ACTIVE=dev \
  -e DB_HOST=host.docker.internal \
  -e DB_PORT=5432 \
  -e DB_NAME=ecommerce_db \
  -e DB_USER=postgres \
  -e DB_PASSWORD=postgres \
  -e REDIS_HOST=host.docker.internal \
  -e REDIS_PORT=6379 \
  -e KAFKA_BOOTSTRAP_SERVERS=host.docker.internal:9092 \
  ecommerce-ciam:local
```

> On Linux, use `--network host` instead of `host.docker.internal`:
> ```bash
> docker run -d --name ecommerce-app -p 8080:8080 \
>   -e SPRING_PROFILES_ACTIVE=dev \
>   --network host \
>   ecommerce-ciam:local
> ```

### 10.3 Check Container Logs

```bash
docker logs -f ecommerce-app
# Watch for: "Started ECommerceApplication in X.XXX seconds"
```

### 10.4 Verify

```bash
curl -s http://localhost:8080/actuator/health
# Expected: {"status":"UP"}
```

### 10.5 Stop the Container

```bash
docker stop ecommerce-app && docker rm ecommerce-app
```

---

## 11. AWS Account & CLI Setup

> **Skip Steps 11–19 if you only need local development.** These steps provision real AWS infrastructure.

### 11.1 AWS Account Requirements

- Active AWS account with billing enabled
- IAM user or role with the following permissions:
  - `AdministratorAccess` for initial setup (can be scoped down after)
  - Or the specific policies: `AmazonEKSFullAccess`, `AmazonRDSFullAccess`, `ElastiCacheFullAccess`, `AmazonMSKFullAccess`, `IAMFullAccess`, `AmazonVPCFullAccess`, `AmazonS3FullAccess`, `AmazonDynamoDBFullAccess`

### 11.2 Configure AWS CLI

```bash
aws configure
```

You will be prompted for:
```
AWS Access Key ID [None]:     <your-access-key-id>
AWS Secret Access Key [None]: <your-secret-access-key>
Default region name [None]:   us-east-1
Default output format [None]: json
```

**Verify:**
```bash
aws sts get-caller-identity
```

**Expected:**
```json
{
    "UserId": "AIDAXXXXXXXXXXXXXXXXX",
    "Account": "123456789012",
    "Arn": "arn:aws:iam::123456789012:user/your-username"
}
```

### 11.3 Configure Named Profiles (Optional — Recommended for Multi-Account)

```bash
# Dev account
aws configure --profile ecommerce-dev

# Prod account
aws configure --profile ecommerce-prod
```

Use profiles in commands:
```bash
aws s3 ls --profile ecommerce-dev
```

---

## 12. Terraform State Bootstrap (One-Time)

Terraform stores its state in S3 with DynamoDB locking. This S3 bucket and DynamoDB table must be created **before** running any Terraform modules. This is a one-time setup per AWS account.

### 12.1 Create the S3 State Bucket

```bash
# Replace YOUR_ACCOUNT_ID with your actual AWS account ID
aws s3api create-bucket \
  --bucket ecommerce-ciam-terraform-state \
  --region us-east-1

# Enable versioning (required — Terraform state must be versioned)
aws s3api put-bucket-versioning \
  --bucket ecommerce-ciam-terraform-state \
  --versioning-configuration Status=Enabled

# Enable server-side encryption
aws s3api put-bucket-encryption \
  --bucket ecommerce-ciam-terraform-state \
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": {
        "SSEAlgorithm": "aws:kms"
      }
    }]
  }'

# Block all public access
aws s3api put-public-access-block \
  --bucket ecommerce-ciam-terraform-state \
  --public-access-block-configuration \
    BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true
```

### 12.2 Create the DynamoDB Lock Table

```bash
aws dynamodb create-table \
  --table-name ecommerce-ciam-terraform-locks \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region us-east-1
```

**Verify:**
```bash
aws dynamodb describe-table \
  --table-name ecommerce-ciam-terraform-locks \
  --query 'Table.TableStatus'
# Expected: "ACTIVE"
```

---

## 13. Provision Dev Infrastructure via Terraform

### 13.1 Navigate to Dev Environment

```bash
cd terraform/environments/dev
```

### 13.2 Initialise Terraform

```bash
terraform init
```

**Expected:**
```
Initializing the backend...
Initializing provider plugins...
- Finding hashicorp/aws versions matching "~> 5.40"...
- Installing hashicorp/aws v5.xx.x...
Terraform has been successfully initialized!
```

### 13.3 Review the Plan

```bash
terraform plan -out=dev.tfplan
```

This shows every resource that will be created. Review carefully — it should show ~80-120 resources including VPC, EKS, Aurora, ElastiCache, MSK, etc.

**Expected end of plan:**
```
Plan: XX to add, 0 to change, 0 to destroy.
```

### 13.4 Apply the Plan

```bash
terraform apply dev.tfplan
```

Type `yes` when prompted. This takes **15–25 minutes** on first run (Aurora and EKS cluster creation are slow).

**Expected end:**
```
Apply complete! Resources: XX added, 0 changed, 0 destroyed.

Outputs:
eks_cluster_name     = "ecommerce-ciam-dev-eks"
aurora_endpoint      = "ecommerce-ciam-dev.cluster-xxx.us-east-1.rds.amazonaws.com"
redis_endpoint       = "ecommerce-ciam-dev.xxx.0001.use1.cache.amazonaws.com"
kafka_bootstrap      = "b-1.ecommerce-ciam-dev.xxx.kafka.us-east-1.amazonaws.com:9092"
```

Save these output values — they will be used in the next steps.

### 13.5 Store Outputs as Environment Variables

```bash
# Capture Terraform outputs
export EKS_CLUSTER=$(terraform output -raw eks_cluster_name)
export DB_HOST=$(terraform output -raw aurora_endpoint)
export REDIS_ENDPOINT=$(terraform output -raw redis_endpoint)
export KAFKA_BOOTSTRAP=$(terraform output -raw kafka_bootstrap)

echo "EKS: $EKS_CLUSTER"
echo "DB:  $DB_HOST"
echo "Redis: $REDIS_ENDPOINT"
echo "Kafka: $KAFKA_BOOTSTRAP"
```

---

## 14. Connect kubectl to EKS

### 14.1 Update kubeconfig

```bash
aws eks update-kubeconfig \
  --name $EKS_CLUSTER \
  --region us-east-1
```

**Expected:**
```
Updated context arn:aws:eks:us-east-1:XXXX:cluster/ecommerce-ciam-dev-eks in /Users/.../kube/config
```

### 14.2 Verify Connection

```bash
kubectl get nodes
```

**Expected:**
```
NAME                            STATUS   ROLES    AGE   VERSION
ip-10-0-1-xxx.ec2.internal      Ready    <none>   5m    v1.31.x
ip-10-0-2-xxx.ec2.internal      Ready    <none>   5m    v1.31.x
```

### 14.3 Verify Cluster Info

```bash
kubectl cluster-info
# Expected: Kubernetes control plane is running at https://xxx.gr7.us-east-1.eks.amazonaws.com
```

---

## 15. Deploy to Kubernetes (Dev)

### 15.1 Build and Push Docker Image to ECR

Get the ECR registry URL:
```bash
ECR_REGISTRY=$(aws ecr describe-repositories \
  --repository-names ecommerce-ciam \
  --query 'repositories[0].repositoryUri' \
  --output text)

echo "ECR: $ECR_REGISTRY"
```

Authenticate Docker to ECR:
```bash
aws ecr get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin $ECR_REGISTRY
```

Build and push:
```bash
# From project root
docker build -t ecommerce-ciam:latest .
docker tag ecommerce-ciam:latest $ECR_REGISTRY:latest
docker tag ecommerce-ciam:latest $ECR_REGISTRY:$(git rev-parse --short HEAD)
docker push $ECR_REGISTRY:latest
docker push $ECR_REGISTRY:$(git rev-parse --short HEAD)
```

### 15.2 Store Secrets in Kubernetes

Create the namespace first:
```bash
kubectl apply -f k8s/base/namespace.yaml
```

Create the application secrets (using values from AWS Secrets Manager / Terraform outputs):
```bash
kubectl create secret generic ecommerce-ciam-secrets \
  --namespace ecommerce-ciam \
  --from-literal=DB_HOST="$DB_HOST" \
  --from-literal=DB_PORT="5432" \
  --from-literal=DB_NAME="ecommerce_db" \
  --from-literal=DB_USER="$(aws secretsmanager get-secret-value \
      --secret-id ecommerce-ciam-dev/db-credentials \
      --query SecretString --output text | python3 -c 'import json,sys; print(json.load(sys.stdin)["username"])')" \
  --from-literal=DB_PASSWORD="$(aws secretsmanager get-secret-value \
      --secret-id ecommerce-ciam-dev/db-credentials \
      --query SecretString --output text | python3 -c 'import json,sys; print(json.load(sys.stdin)["password"])')" \
  --from-literal=REDIS_HOST="$REDIS_ENDPOINT" \
  --from-literal=KAFKA_BOOTSTRAP_SERVERS="$KAFKA_BOOTSTRAP"
```

### 15.3 Deploy via Kustomize (Dev Overlay)

```bash
# From project root
kustomize build k8s/overlays/dev | kubectl apply -f -
```

**Expected:**
```
namespace/ecommerce-ciam configured
deployment.apps/identity-service created
service/identity-service created
horizontalpodautoscaler.autoscaling/identity-service created
...
```

### 15.4 Verify Deployment

```bash
# Watch pods come up (Ctrl+C to stop watching)
kubectl get pods -n ecommerce-ciam -w
```

**Expected (all pods Running):**
```
NAME                               READY   STATUS    RESTARTS
identity-service-xxx-yyy           1/1     Running   0
session-service-xxx-yyy            1/1     Running   0
notification-service-xxx-yyy       1/1     Running   0
audit-service-xxx-yyy              1/1     Running   0
```

### 15.5 Check Pod Logs

```bash
kubectl logs -n ecommerce-ciam \
  $(kubectl get pods -n ecommerce-ciam -l app=identity-service -o name | head -1) \
  --tail=50
```

**Expected:** Same startup sequence as local, ending with "Started ECommerceApplication"

### 15.6 Port-Forward to Test Locally

```bash
kubectl port-forward -n ecommerce-ciam \
  svc/identity-service 8080:8080
```

Then in another terminal:
```bash
curl -s http://localhost:8080/actuator/health
# Expected: {"status":"UP"}
```

---

## 16. Set Up ArgoCD GitOps

ArgoCD watches the `k8s/` directory in the Git repository and automatically applies changes.

### 16.1 Install ArgoCD in the Cluster

```bash
kubectl create namespace argocd
kubectl apply -n argocd -f \
  https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

Wait for ArgoCD to be ready:
```bash
kubectl wait --for=condition=available deployment/argocd-server \
  -n argocd --timeout=120s
```

### 16.2 Apply ArgoCD Application Definitions

```bash
kubectl apply -f k8s/argocd/ -n argocd
```

### 16.3 Get ArgoCD Initial Admin Password

```bash
kubectl get secret argocd-initial-admin-secret \
  -n argocd \
  -o jsonpath="{.data.password}" | base64 -d
```

### 16.4 Access ArgoCD UI

```bash
kubectl port-forward svc/argocd-server -n argocd 8443:443
```

Open: https://localhost:8443
- Username: `admin`
- Password: from Step 16.3

**Expected:** ArgoCD dashboard showing the `ecommerce-ciam-dev` application, status: `Synced`

---

## 17. CI/CD — GitHub Actions Setup

### 17.1 Required GitHub Repository Secrets

Go to your GitHub repository → Settings → Secrets and Variables → Actions.

Add the following secrets:

| Secret Name | Value | Description |
|---|---|---|
| `AWS_ACCESS_KEY_ID` | Your AWS Access Key | CI/CD AWS authentication |
| `AWS_SECRET_ACCESS_KEY` | Your AWS Secret Key | CI/CD AWS authentication |
| `AWS_REGION` | `us-east-1` | Primary region |
| `ECR_REPOSITORY` | ECR repository URI | Docker image push target |
| `EKS_CLUSTER_NAME` | `ecommerce-ciam-dev-eks` | Cluster name for ArgoCD sync |
| `SONAR_TOKEN` | SonarQube/SonarCloud token | SAST scanning |
| `SONAR_HOST_URL` | SonarQube server URL | SAST scanning |

### 17.2 Workflow Overview

| Workflow | Trigger | Duration |
|---|---|---|
| `ci.yml` | Every PR to `main` | ~5 min |
| `build-deploy.yml` | Push to `main` | ~10 min |
| `integration-tests.yml` | After build-deploy | ~8 min |
| `performance-test.yml` | Manual / staging deploy | ~15 min |
| `security-scan.yml` | Weekly (Monday 02:00 UTC) | ~20 min |
| `release.yml` | Manual trigger | ~30 min |

### 17.3 Trigger Your First CI Run

```bash
# Create a test branch and push to trigger CI
git checkout -b test/ci-validation
git commit --allow-empty -m "ci: trigger initial CI run"
git push origin test/ci-validation
```

Open a PR from `test/ci-validation` to `main`. The `ci.yml` workflow starts automatically.

**Expected CI checks:**
- `compile` — green
- `test` — green
- `archunit` — green
- `sonarqube` — green (or skipped if token not configured)
- `owasp-dependency-check` — green

---

## 18. Monitoring Stack Setup

### 18.1 Local Monitoring (Prometheus + Grafana)

```bash
docker compose -f monitoring/docker-compose.monitoring.yml up -d
```

**Services started:**

| Service | URL | Credentials |
|---|---|---|
| Grafana | http://localhost:3000 | `admin` / `admin` |
| Prometheus | http://localhost:9090 | — |
| AlertManager | http://localhost:9093 | — |

### 18.2 Configure Prometheus Scrape Target

Prometheus is pre-configured to scrape the application at `localhost:8080/actuator/prometheus`. Make sure the application is running, then:

```bash
curl -s http://localhost:9090/api/v1/targets | python3 -m json.tool | grep '"health"'
# Expected: "health": "up"
```

### 18.3 Import Grafana Dashboards

1. Open Grafana at http://localhost:3000 and log in
2. Go to Dashboards → Import
3. Import each dashboard from `monitoring/grafana/dashboards/`:
   - `auth-overview.json`
   - `session-health.json`
   - `auth-slo.json`
   - `kafka-events.json`
   - `infrastructure.json`
   - `security.json`

**Or import via API:**
```bash
for dashboard in monitoring/grafana/dashboards/*.json; do
  curl -s -X POST \
    -H "Content-Type: application/json" \
    -d "{\"dashboard\": $(cat $dashboard), \"overwrite\": true}" \
    http://admin:admin@localhost:3000/api/dashboards/import
done
```

### 18.4 Deploy Monitoring to Kubernetes (Production)

```bash
# Apply Prometheus + Grafana via Helm (if using kube-prometheus-stack)
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

helm install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace \
  --values monitoring/helm-values.yaml
```

---

## 19. Staging & Production Deployment

### 19.1 Staging

```bash
cd terraform/environments/staging
terraform init
terraform plan -out=staging.tfplan
terraform apply staging.tfplan
```

Update GitHub Actions secret `EKS_CLUSTER_NAME` with the staging cluster name, then merge to `main` — ArgoCD will deploy to staging automatically.

### 19.2 Production

**Production deployment requires:**
1. All staging tests passing (Gatling 10K req/s + OWASP ZAP DAST)
2. Manual approval gate in GitHub Actions
3. Canary deployment: 5% → 25% → 50% → 100% with error-rate gate

```bash
# Trigger via GitHub Actions (manual workflow dispatch)
# Go to Actions → release.yml → Run workflow → select prod-us

# Or via CLI
gh workflow run release.yml \
  --field environment=prod-us \
  --field confirm=yes
```

**Canary rollout is managed by ArgoCD + Argo Rollouts:**
```bash
# Watch canary progress
kubectl argo rollouts get rollout identity-service \
  -n ecommerce-ciam --watch
```

---

## 20. Complete Verification Checklist

Run through this checklist after every fresh setup to confirm everything is working.

### Local Development

| # | Check | Command | Expected |
|---|---|---|---|
| 1 | Java version | `java -version` | `21.x.x` |
| 2 | Maven version | `mvn -version` | `3.9.x, Java 21` |
| 3 | Docker running | `docker info` | No error |
| 4 | All containers healthy | `docker compose ps` | All `healthy` |
| 5 | PostgreSQL ready | `docker exec ecommerce-postgres pg_isready -U postgres` | `accepting connections` |
| 6 | Redis ready | `docker exec ecommerce-redis redis-cli ping` | `PONG` |
| 7 | Kafka ready | `docker exec ecommerce-kafka /opt/kafka/bin/kafka-broker-api-versions.sh --bootstrap-server localhost:9092` | Shows version |
| 8 | OpenSearch ready | `curl -s localhost:9200/_cluster/health` | `"status":"green"` or `"yellow"` |
| 9 | RSA keys present | `ls src/main/resources/keys/` | `dev-private.pem dev-public.pem` |
| 10 | Key format correct | `head -1 src/main/resources/keys/dev-private.pem` | `-----BEGIN PRIVATE KEY-----` |
| 11 | Compile | `mvn compile` | `BUILD SUCCESS` |
| 12 | Unit tests | `mvn test` | `BUILD SUCCESS, 0 failures` |
| 13 | App starts | `mvn spring-boot:run -Dspring-boot.run.profiles=dev` | `Started ECommerceApplication` |
| 14 | Health endpoint | `curl localhost:8080/actuator/health` | `{"status":"UP"}` |
| 15 | DB health | Health response `components.db.status` | `UP` |
| 16 | Redis health | Health response `components.redis.status` | `UP` |
| 17 | Flyway ran | `docker exec ecommerce-postgres psql -U postgres -d ecommerce_db -c "\dt identity.*"` | 6 tables listed |
| 18 | Swagger UI | `curl -o /dev/null -s -w "%{http_code}" localhost:8080/swagger-ui.html` | `200` |
| 19 | Prometheus | `curl -s localhost:8080/actuator/prometheus \| head -5` | Metric lines |
| 20 | ArchUnit tests | `mvn test -Dtest=PackageBoundaryTest` | `PASS` |

### Cloud / Kubernetes

| # | Check | Command | Expected |
|---|---|---|---|
| 21 | AWS auth | `aws sts get-caller-identity` | Account JSON |
| 22 | EKS connection | `kubectl get nodes` | Nodes `Ready` |
| 23 | Pods running | `kubectl get pods -n ecommerce-ciam` | All `Running` |
| 24 | App health via K8s | `kubectl port-forward svc/identity-service 8080:8080 -n ecommerce-ciam` then `curl localhost:8080/actuator/health` | `UP` |
| 25 | ArgoCD synced | ArgoCD UI → app status | `Synced` / `Healthy` |
| 26 | Monitoring up | http://localhost:3000 (Grafana) | Dashboards visible |

---

## 21. Environment Variable Reference

### Local Dev (Defaults — no action needed)

All defaults are set in `application-dev.yml` and `application.yml`.

| Variable | Default | Configurable? |
|---|---|---|
| `DB_HOST` | `localhost` | Yes |
| `DB_PORT` | `5432` | Yes |
| `DB_NAME` | `ecommerce_db` | Yes |
| `DB_USER` | `postgres` | Yes |
| `DB_PASSWORD` | `postgres` | Yes |
| `REDIS_HOST` | `localhost` | Yes |
| `REDIS_PORT` | `6379` | Yes |
| `REDIS_PASSWORD` | *(empty)* | Yes |
| `KAFKA_BOOTSTRAP_SERVERS` | `localhost:9092` | Yes |

### Staging / Production (Required — must be set)

| Variable | Where it comes from | Description |
|---|---|---|
| `DB_HOST` | Terraform output `aurora_endpoint` | Aurora PostgreSQL host |
| `DB_PORT` | `5432` | Always 5432 |
| `DB_NAME` | `ecommerce_db` | Database name |
| `DB_USER` | AWS Secrets Manager | Rotated automatically |
| `DB_PASSWORD` | AWS Secrets Manager | Rotated automatically |
| `REDIS_HOST` | Terraform output `redis_endpoint` | ElastiCache Redis host |
| `REDIS_CLUSTER_NODES` | Terraform output (all cluster nodes) | Comma-separated Redis cluster nodes |
| `REDIS_PASSWORD` | AWS Secrets Manager | Auth token |
| `KAFKA_BOOTSTRAP_SERVERS` | Terraform output `kafka_bootstrap` | MSK Kafka brokers |
| `JWT_PUBLIC_KEY_PATH` | Mounted from K8s secret | Path to RSA public key PEM |
| `JWT_PRIVATE_KEY_PATH` | Mounted from K8s secret / KMS | Path to RSA private key PEM |
| `SPRING_PROFILES_ACTIVE` | K8s deployment env | `staging` or `prod` |

---

## 22. Troubleshooting

### App won't start: "Could not connect to PostgreSQL"

```
com.zaxxer.hikari.pool.HikariPool$PoolInitializationException: Failed to initialize pool
Caused by: org.postgresql.util.PSQLException: Connection refused
```

**Fix:**
```bash
# 1. Check Docker is running
docker ps

# 2. Check postgres container
docker compose ps postgres
# Should show: Up (healthy)

# 3. If not running, start it
docker compose up -d postgres

# 4. Test connection manually
docker exec ecommerce-postgres pg_isready -U postgres
```

---

### App won't start: "Cannot decrypt JWT" or "Failed to read RSA key"

```
java.lang.IllegalArgumentException: Failed to decode RSA Public Key
```

**Fix:**
```bash
# Check the key exists and is PKCS#8 format
head -1 src/main/resources/keys/dev-private.pem
# MUST be: -----BEGIN PRIVATE KEY-----
# NOT:     -----BEGIN RSA PRIVATE KEY-----

# If wrong format, re-generate:
cd src/main/resources/keys
openssl genrsa -out raw.pem 2048
openssl rsa -in raw.pem -pubout -out dev-public.pem
openssl pkcs8 -topk8 -inform PEM -outform PEM -nocrypt -in raw.pem -out dev-private.pem
rm raw.pem
```

---

### Flyway error: "Found non-empty schema(s) without schema history table"

```
org.flywaydb.core.api.exception.FlywayValidateException:
Found non-empty schema(s) without schema history table
```

**Fix:**
```bash
# This happens when the public schema already exists and baseline wasn't applied
# Enable baseline in application-dev.yml:
#   spring.flyway.baseline-on-migrate: true
# This is already set in the project config — restart the app
```

---

### Flyway error: "Migration checksum mismatch"

```
FlywayException: Validate failed: Detected failed migration to version X
```

**Fix:**
```bash
# Do NOT repair production. For dev only:
docker exec ecommerce-postgres psql -U postgres -d ecommerce_db \
    -c "DELETE FROM flyway_schema_history WHERE success = FALSE;"
# Then restart the app
```

---

### Kafka container won't start

```
ecommerce-kafka   Exiting (1)
```

**Fix:**
```bash
# Check logs
docker compose logs kafka

# Common issue: Kafka volume has stale state — clear it
docker compose down -v kafka
docker compose up -d kafka
docker compose ps kafka
# Wait 30 seconds, should show "healthy"
```

---

### Kafka ADVERTISED_LISTENERS warning in app logs

```
WARN Connection to node 1 could not be established
```

**Fix:** This happens when the Spring app inside Docker can't reach Kafka on `localhost:9092`. When running the app via Docker (Step 10), make sure `KAFKA_BOOTSTRAP_SERVERS` is set to `host.docker.internal:9092` (macOS/Windows) or the host IP (Linux).

---

### OpenSearch container very slow / out of memory

```
ecommerce-opensearch   Up (unhealthy)
```

**Fix:**
```bash
# Increase Docker memory allocation in Docker Desktop:
# Docker Desktop → Settings → Resources → Memory → set to at least 4GB

# Or reduce OpenSearch memory in docker-compose.yml:
# OPENSEARCH_JAVA_OPTS: "-Xms256m -Xmx256m"   (already set at 512m)
```

---

### ArchUnit test failure: "classes that reside in a package 'identity..' should not depend on classes in package 'profile..'"

This is not an error in the test — it is catching a real violation.

**Fix:** Find the class that imports from another bounded context, and replace the direct import with a domain event or move the shared code to the `shared` package.

```bash
# Find the offending import
mvn test -Dtest=PackageBoundaryTest 2>&1 | grep "Architecture Violation"
```

---

### Maven out of memory during build

```
OutOfMemoryError: Java heap space
```

**Fix:**
```bash
export MAVEN_OPTS="-Xmx2g -XX:MaxMetaspaceSize=512m"
mvn compile
```

---

### Terraform: "Error acquiring state lock"

```
Error: Error acquiring the state lock
Lock Info:
  ID: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
```

**Fix:** Another Terraform process is running, or a previous one crashed without releasing the lock.

```bash
# Force-unlock (use the Lock ID from the error message)
terraform force-unlock xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
```

---

### kubectl: "error: You must be logged in to the server"

```
error: You must be logged in to the server (Unauthorized)
```

**Fix:**
```bash
# Refresh EKS token
aws eks update-kubeconfig \
  --name $EKS_CLUSTER_NAME \
  --region us-east-1

# Verify
kubectl get nodes
```

---

## Quick Reference — Most Used Commands

```bash
# Start infrastructure
docker compose up -d

# Stop infrastructure (keep data)
docker compose stop

# Stop infrastructure and DELETE all data
docker compose down -v

# Start application
mvn spring-boot:run -Dspring-boot.run.profiles=dev

# Run all tests
mvn test

# Run only ArchUnit tests
mvn test -Dtest=PackageBoundaryTest,CodingConventionTest

# Build JAR
mvn clean package -DskipTests

# Build Docker image
docker build -t ecommerce-ciam:local .

# Health check
curl -s http://localhost:8080/actuator/health | python3 -m json.tool

# View app logs (Docker)
docker logs -f ecommerce-app

# View K8s pod logs
kubectl logs -n ecommerce-ciam -l app=identity-service --tail=100 -f

# View DB tables
docker exec ecommerce-postgres psql -U postgres -d ecommerce_db -c "\dt identity.*"

# Flush Redis (dev only!)
docker exec ecommerce-redis redis-cli FLUSHALL

# List Kafka topics
docker exec ecommerce-kafka /opt/kafka/bin/kafka-topics.sh \
    --bootstrap-server localhost:9092 --list

# Start local monitoring
docker compose -f monitoring/docker-compose.monitoring.yml up -d

# Terraform plan (dev)
cd terraform/environments/dev && terraform plan

# Deploy to K8s (dev)
kustomize build k8s/overlays/dev | kubectl apply -f -
```

---

*Guide version: February 24, 2026*
*Stack: Spring Boot 3.4.2 / Java 21 / PostgreSQL 16 / Redis 7 / Kafka 3.8 / AWS EKS 1.31*
