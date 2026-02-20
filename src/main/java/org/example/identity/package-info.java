/**
 * Identity bounded context — authentication, registration, MFA, sessions, devices, social login.
 * May depend on: shared.
 * Must NOT depend on: profile, notification, audit.
 * Communicates with other contexts via domain events (Kafka).
 */
package org.example.identity;
