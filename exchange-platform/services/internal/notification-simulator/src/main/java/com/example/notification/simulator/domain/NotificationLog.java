package com.example.notification.simulator.domain;

import lombok.Builder;
import lombok.Data;
import java.time.Instant;

@Data
@Builder
public class NotificationLog {
    private Instant timestamp;
    private String channel;
    private String destination;
    private String payload;
    private String status;
}
