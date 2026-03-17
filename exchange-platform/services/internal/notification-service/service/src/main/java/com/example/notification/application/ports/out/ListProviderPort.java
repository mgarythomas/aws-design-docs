package com.example.notification.application.ports.out;

import com.example.notification.domain.Subscriber;

/**
 * Outbound port: contract the domain requires for managing distribution lists
 * on the external notification provider (e.g., SFMC Data Extensions).
 */
public interface ListProviderPort {

    /**
     * Creates a new distribution list on the provider and returns its external key.
     *
     * @param name human-readable list name
     * @return the provider-assigned external key (e.g., SFMC DataExtensionKey)
     */
    String createList(String name);

    /**
     * Adds a subscriber record to the provider's distribution list.
     *
     * @param externalKey the provider key of the target list
     * @param subscriber  the subscriber to add
     */
    void addSubscriber(String externalKey, Subscriber subscriber);

    /**
     * Removes a subscriber from the provider's distribution list.
     *
     * @param externalKey  the provider key of the target list
     * @param subscriberId the domain identifier of the subscriber to remove
     */
    void removeSubscriber(String externalKey, String subscriberId);
}
