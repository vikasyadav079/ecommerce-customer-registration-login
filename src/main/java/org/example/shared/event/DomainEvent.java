package org.example.shared.event;

import java.time.Instant;
import java.util.Map;
import java.util.UUID;

public abstract class DomainEvent {

    private final UUID eventId;
    private final String eventType;
    private final Instant occurredAt;
    private final UUID customerId;
    private final Map<String, Object> metadata;

    protected DomainEvent(String eventType, UUID customerId, Map<String, Object> metadata) {
        this.eventId = UUID.randomUUID();
        this.eventType = eventType;
        this.occurredAt = Instant.now();
        this.customerId = customerId;
        this.metadata = metadata != null ? metadata : Map.of();
    }

    protected DomainEvent(String eventType, UUID customerId) {
        this(eventType, customerId, Map.of());
    }

    public UUID getEventId() { return eventId; }
    public String getEventType() { return eventType; }
    public Instant getOccurredAt() { return occurredAt; }
    public UUID getCustomerId() { return customerId; }
    public Map<String, Object> getMetadata() { return metadata; }
}
