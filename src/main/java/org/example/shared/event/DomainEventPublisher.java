package org.example.shared.event;

public interface DomainEventPublisher {

    void publish(String topic, DomainEvent event);

    void publish(String topic, String key, DomainEvent event);
}
