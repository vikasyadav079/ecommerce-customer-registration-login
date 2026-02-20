package org.example.shared.config;

import org.apache.kafka.clients.admin.NewTopic;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.kafka.config.TopicBuilder;

@Configuration
public class KafkaTopicConfig {

    private static final int HIGH_VOLUME_PARTITIONS = 12;
    private static final int STANDARD_PARTITIONS = 6;
    private static final short REPLICATION_FACTOR = 1; // Override to 3 in production

    @Bean
    public NewTopic authLoginEvents() {
        return TopicBuilder.name("auth.login.events")
                .partitions(HIGH_VOLUME_PARTITIONS)
                .replicas(REPLICATION_FACTOR)
                .build();
    }

    @Bean
    public NewTopic authRegistrationEvents() {
        return TopicBuilder.name("auth.registration.events")
                .partitions(STANDARD_PARTITIONS)
                .replicas(REPLICATION_FACTOR)
                .build();
    }

    @Bean
    public NewTopic authPasswordEvents() {
        return TopicBuilder.name("auth.password.events")
                .partitions(STANDARD_PARTITIONS)
                .replicas(REPLICATION_FACTOR)
                .build();
    }

    @Bean
    public NewTopic authSessionEvents() {
        return TopicBuilder.name("auth.session.events")
                .partitions(HIGH_VOLUME_PARTITIONS)
                .replicas(REPLICATION_FACTOR)
                .build();
    }

    @Bean
    public NewTopic authSecurityEvents() {
        return TopicBuilder.name("auth.security.events")
                .partitions(STANDARD_PARTITIONS)
                .replicas(REPLICATION_FACTOR)
                .build();
    }

    @Bean
    public NewTopic authAuditEvents() {
        return TopicBuilder.name("auth.audit.events")
                .partitions(HIGH_VOLUME_PARTITIONS)
                .replicas(REPLICATION_FACTOR)
                .build();
    }

    @Bean
    public NewTopic notificationsEmail() {
        return TopicBuilder.name("notifications.email")
                .partitions(STANDARD_PARTITIONS)
                .replicas(REPLICATION_FACTOR)
                .build();
    }

    @Bean
    public NewTopic notificationsSms() {
        return TopicBuilder.name("notifications.sms")
                .partitions(STANDARD_PARTITIONS)
                .replicas(REPLICATION_FACTOR)
                .build();
    }
}
