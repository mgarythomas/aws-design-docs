package com.example.notification.domain;

import lombok.Builder;
import lombok.Getter;

import java.util.Map;
import java.util.UUID;

/**
 * Core domain aggregate representing a notification intent.
 * Use {@link RecipientType#SINGLE} with a {@code destination} address,
 * or {@link RecipientType#LIST} with a {@code listId} for broadcast sends.
 */
@Getter
@Builder
public class Notification {

    public enum RecipientType { SINGLE, LIST }

    private final UUID id;
    private final String channel;
    private final RecipientType recipientType;

    /** Required when recipientType is SINGLE. */
    private final String destination;

    /** Required when recipientType is LIST. Maps to a DistributionList id. */
    private final UUID listId;

    private final String source;
    private final String templateId;
    private final Map<String, Object> templatePayload;

    /** Convenience factory for single-address notifications. */
    public static Notification createSingle(String channel, String destination, String source,
            String templateId, Map<String, Object> templatePayload) {
        return Notification.builder()
                .id(UUID.randomUUID())
                .channel(channel)
                .recipientType(RecipientType.SINGLE)
                .destination(destination)
                .source(source)
                .templateId(templateId)
                .templatePayload(templatePayload)
                .build();
    }

    /** Convenience factory for list-targeted notifications. */
    public static Notification createForList(String channel, UUID listId, String source,
            String templateId, Map<String, Object> templatePayload) {
        return Notification.builder()
                .id(UUID.randomUUID())
                .channel(channel)
                .recipientType(RecipientType.LIST)
                .listId(listId)
                .source(source)
                .templateId(templateId)
                .templatePayload(templatePayload)
                .build();
    }

    /** @deprecated Use {@link #createSingle} or {@link #createForList} instead. */
    @Deprecated
    public static Notification create(String channel, String destination, String source,
            String templateId, Map<String, Object> templatePayload) {
        return createSingle(channel, destination, source, templateId, templatePayload);
    }
}
