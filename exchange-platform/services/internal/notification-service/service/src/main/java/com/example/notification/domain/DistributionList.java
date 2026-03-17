package com.example.notification.domain;

import lombok.Builder;
import lombok.Getter;

import java.time.Instant;
import java.util.UUID;

/**
 * Domain aggregate representing a distribution list.
 * The {@code externalKey} maps to the SFMC DataExtensionKey assigned
 * by the provider upon creation and is used for all subsequent sends.
 */
@Getter
@Builder
public class DistributionList {

    private final UUID id;
    private final String name;
    private final String description;

    /** The SFMC Data Extension key persisted after remote creation. */
    private final String externalKey;

    private final int subscriberCount;
    private final Instant createdAt;

    public static DistributionList create(String name, String description) {
        return DistributionList.builder()
                .id(UUID.randomUUID())
                .name(name)
                .description(description)
                .subscriberCount(0)
                .createdAt(Instant.now())
                .build();
    }

    public DistributionList withExternalKey(String externalKey) {
        return DistributionList.builder()
                .id(this.id)
                .name(this.name)
                .description(this.description)
                .externalKey(externalKey)
                .subscriberCount(this.subscriberCount)
                .createdAt(this.createdAt)
                .build();
    }
}
