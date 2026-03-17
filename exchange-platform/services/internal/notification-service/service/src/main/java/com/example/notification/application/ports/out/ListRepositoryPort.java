package com.example.notification.application.ports.out;

import com.example.notification.domain.DistributionList;

import java.util.Optional;
import java.util.UUID;

/**
 * Outbound port: contract for persisting and retrieving distribution list state
 * in the platform's internal database.
 */
public interface ListRepositoryPort {

    DistributionList save(DistributionList list);

    Optional<DistributionList> findById(UUID listId);
}
