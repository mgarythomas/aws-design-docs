package com.example.notification.application.ports.in;

import com.example.notification.domain.DistributionList;
import com.example.notification.domain.Subscriber;

import java.util.List;
import java.util.UUID;

/**
 * Inbound port: exposes distribution list management operations to the outside world.
 * Controllers and other primary adapters invoke these methods to drive the domain.
 */
public interface ListManagementUseCase {

    DistributionList createList(String name, String description);

    DistributionList getList(UUID listId);

    void addSubscribers(UUID listId, List<Subscriber> subscribers);

    void removeSubscriber(UUID listId, String subscriberId);
}
