package com.example.notification.adapters.out.audit;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;

import java.time.Instant;
import java.util.UUID;

@Entity
@Getter
@Setter
@Table(name = "distribution_lists")
public class DistributionListEntity {

    @Id
    private UUID id;

    @Column(nullable = false)
    private String name;

    private String description;

    /** The SFMC DataExtensionKey assigned by the provider upon list creation. */
    @Column(name = "external_key")
    private String externalKey;

    @Column(name = "subscriber_count")
    private int subscriberCount;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;
}
