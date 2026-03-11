package com.example.notification.adapters.out.audit;

import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import lombok.Getter;
import lombok.Setter;
import java.util.UUID;
import java.time.Instant;

@Entity
@Getter
@Setter
@Table(name = "notification_audits")
public class AuditEntity {
    @Id
    private UUID notificationId;
    private String channel;
    private String source;
    private String destination;
    private String status;
    private Instant createdAt = Instant.now();
}
