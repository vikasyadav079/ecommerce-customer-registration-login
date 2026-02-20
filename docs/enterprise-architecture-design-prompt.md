# Enterprise Architecture Design Prompt
> Use this file as a prompt with Claude (or any AI) to get a complete, tailored enterprise-level technical architecture.
> Fill in all sections before submitting. Leave fields as "Unknown" if not yet determined.

---

## ROLE

You are a Senior Enterprise Architect with 20+ years of experience in designing
robust, scalable, maintainable, and secure enterprise-level systems.

I need your help designing a complete technical architecture for my project.
I will provide you with my functional requirements and context below. Based on
this, guide me through the full architectural process.

---

## PROJECT CONTEXT

- **Business Domain:** [e-commerce]
- **Project Type:** [Greenfield]
- **End Users:** [all three]
- **Team Size:** [multiple squads]
- **Timeline:** [full product in 12 months]
- **Budget Envelope:** [enterprise]

---

## FUNCTIONAL REQUIREMENTS

customer-auth-complete-functional-requirements.md

---

## NON-FUNCTIONAL REQUIREMENTS

> Fill what you know. Leave blank or write "Unknown" if not yet defined.

| Attribute            | Value                                              |
|----------------------|----------------------------------------------------|
| Availability SLA     | [e.g., 99.9% / 99.99%]                            |
| Expected Users       | [e.g., 1,000 DAU now → 500,000 DAU in 2 years]   |
| Peak Throughput      | [e.g., 500 requests/sec at peak]                  |
| Acceptable Latency   | [e.g., <200ms for API responses]                  |
| Data Volume          |           |
| RTO                  |                                |
| RPO                  |                               |
| Compliance           |    |

---

## TECHNICAL CONTEXT

customer-auth-tech-stack-spring-java.md

---

## SECURITY & COMPLIANCE POSTURE

- **Authentication Model:** []
- **Authorization Model:** []
- **Multi-Tenancy Required:** []
- **Data Sensitivity:** []
- **Network Model:** []

---

## WHAT I NEED FROM YOU

Please provide the following in sequence:

### 1. Architecture Assessment
- Identify risks, gaps, and unknowns in my requirements
- Flag any missing information critical to architecture decisions
- Highlight constraints that will significantly shape the design

### 2. Recommended Architectural Style
- Suggest the best pattern (Monolith / Modular Monolith / Microservices /
  Event-Driven / Serverless / Hybrid) with clear justification
- Explain trade-offs of the recommended approach vs alternatives

### 3. Domain Model
- Identify core bounded contexts and their relationships
- Suggest domain events if event-driven patterns apply
- Highlight shared kernel or integration patterns between domains

### 4. System Architecture Design
- **Context Diagram:** system actors and external dependencies
- **Container Diagram:** major deployable components and communication patterns
- **Data Architecture:** ownership, storage strategy, consistency model
- **Integration Architecture:** sync vs async, API gateway, messaging

### 5. Technology Stack Recommendation
- Frontend, Backend, Database, Messaging, Cache, Search, Storage
- DevOps toolchain: CI/CD, IaC, container orchestration
- Observability stack: logging, tracing, metrics
- Justify each choice against my constraints and team skills

### 6. Security Architecture
- AuthN/AuthZ implementation plan
- Secrets and certificate management
- Network segmentation and API security
- Threat model highlights (STRIDE-based)
- Data encryption strategy (in transit + at rest)

### 7. Scalability & Resilience Plan
- Horizontal vs vertical scaling strategy per component
- Caching strategy (L1 / L2 / CDN)
- Resilience patterns: circuit breaker, retry, bulkhead, graceful degradation
- Database scaling: read replicas, sharding, partitioning if needed

### 8. DevOps & Deployment Architecture
- Environment strategy (dev / staging / prod)
- CI/CD pipeline design
- Infrastructure as Code approach
- Deployment strategy: blue-green / canary / rolling
- Feature flag strategy if applicable

### 9. Implementation Roadmap
- Break the build into phases with clear milestones
- Identify what to build first (core domain vs infrastructure)
- Highlight PoC or spike work needed before committing to tech choices
- Suggest team structure aligned to architecture (Conway's Law)

### 10. Architecture Decision Records (ADRs)
Document the top 5 most critical architectural decisions. For each:
- Context
- Decision
- Alternatives considered
- Trade-offs
- Consequences

### 11. Risk Register
- Top technical risks with likelihood and impact rating
- Mitigation strategy for each risk

---

## OUTPUT INSTRUCTIONS

- Use **Mermaid syntax** for all diagrams where possible
- Use **C4 Model levels** for system diagrams (Context → Container → Component)
- Be **specific** — avoid generic advice, tailor everything to my context above
- **Flag assumptions** you are making where my input is incomplete
- If any critical information is missing, **ask me before proceeding** with that section
- Structure your response using the same numbered sections above

---

*File version: 1.0 | Last updated: February 2026*
*Compatible with: Claude, GPT-4, Gemini, and other LLMs*
