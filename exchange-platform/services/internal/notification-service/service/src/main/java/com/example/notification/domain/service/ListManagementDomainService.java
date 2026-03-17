package com.example.notification.domain.service;

import com.example.notification.application.ports.in.ListManagementUseCase;
import com.example.notification.application.ports.out.ListProviderPort;
import com.example.notification.application.ports.out.ListRepositoryPort;
import com.example.notification.domain.DistributionList;
import com.example.notification.domain.Subscriber;
import org.springframework.stereotype.Service;

import java.util.List;
import java.util.UUID;

/**
 * Domain service that orchestrates distribution list management.
 * Delegates external provider interactions to {@link ListProviderPort} (SFMC)
 * and persistence to {@link ListRepositoryPort} (Postgres).
 */
@Service
public class ListManagementDomainService implements ListManagementUseCase {

    private final ListProviderPort listProviderPort;
    private final ListRepositoryPort listRepositoryPort;

    public ListManagementDomainService(ListProviderPort listProviderPort,
            ListRepositoryPort listRepositoryPort) {
        this.listProviderPort = listProviderPort;
        this.listRepositoryPort = listRepositoryPort;
    }

    @Override
    public DistributionList createList(String name, String description) {
        // Create on provider first; get back the external key (SFMC DataExtensionKey)
        String externalKey = listProviderPort.createList(name);

        DistributionList list = DistributionList.create(name, description)
                .withExternalKey(externalKey);

        return listRepositoryPort.save(list);
    }

    @Override
    public DistributionList getList(UUID listId) {
        return listRepositoryPort.findById(listId)
                .orElseThrow(() -> new IllegalArgumentException("Distribution list not found: " + listId));
    }

    @Override
    public void addSubscribers(UUID listId, List<Subscriber> subscribers) {
        DistributionList list = getList(listId);
        subscribers.forEach(s -> listProviderPort.addSubscriber(list.getExternalKey(), s));
    }

    @Override
    public void removeSubscriber(UUID listId, String subscriberId) {
        DistributionList list = getList(listId);
        listProviderPort.removeSubscriber(list.getExternalKey(), subscriberId);
    }
}
