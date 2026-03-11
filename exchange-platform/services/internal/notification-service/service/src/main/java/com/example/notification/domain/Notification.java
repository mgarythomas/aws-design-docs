package com.example.notification.domain;

import lombok.Builder;
import lombok.Getter;
import java.util.Map;
import java.util.UUID;

@Getter
@Builder
public class Notification {
    private final UUID id;
    private final String channel;
    private final String destination;
    private final String source;
    private final String templateId;
    private final Map<String, Object> templatePayload;

    public static Notification create(String channel, String destination, String source, String templateId,
            Map<String, Object> templatePayload) {
        return Notification.builder()
                .id(UUID.randomUUID())
                .channel(channel)
                .destination(destination)
                .source(source)
                .templateId(templateId)
                .templatePayload(templatePayload)
                .build();
    }
}
