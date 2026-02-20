package org.example.shared.event;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.kafka.core.KafkaTemplate;
import org.springframework.stereotype.Component;

@Component
public class KafkaDomainEventPublisher implements DomainEventPublisher {

    private static final Logger log = LoggerFactory.getLogger(KafkaDomainEventPublisher.class);
    private final KafkaTemplate<String, DomainEvent> kafkaTemplate;

    public KafkaDomainEventPublisher(KafkaTemplate<String, DomainEvent> kafkaTemplate) {
        this.kafkaTemplate = kafkaTemplate;
    }

    @Override
    public void publish(String topic, DomainEvent event) {
        publish(topic, event.getCustomerId() != null ? event.getCustomerId().toString() : null, event);
    }

    @Override
    public void publish(String topic, String key, DomainEvent event) {
        log.debug("Publishing event {} to topic {} with key {}", event.getEventType(), topic, key);
        kafkaTemplate.send(topic, key, event)
                .whenComplete((result, ex) -> {
                    if (ex != null) {
                        log.error("Failed to publish event {} to topic {}", event.getEventId(), topic, ex);
                    } else {
                        log.debug("Event {} published to topic {} partition {} offset {}",
                                event.getEventId(), topic,
                                result.getRecordMetadata().partition(),
                                result.getRecordMetadata().offset());
                    }
                });
    }
}
