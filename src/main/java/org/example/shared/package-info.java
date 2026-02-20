/**
 * Shared kernel — cross-cutting concerns available to all bounded contexts.
 * Contains configuration, domain primitives, events, exceptions, DTOs, security, and utilities.
 * Must NOT depend on any bounded context (identity, profile, notification, audit).
 */
package org.example.shared;
