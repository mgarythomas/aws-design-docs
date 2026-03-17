package com.example.notification.adapters.out.audit;

import com.example.notification.application.ports.out.ListRepositoryPort;
import com.example.notification.domain.DistributionList;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import java.util.Optional;
import java.util.UUID;

/**
 * Secondary adapter implementing {@link ListRepositoryPort} via Spring Data JPA.
 * Persists and retrieves {@link DistributionList} domain objects from the
 * {@code distribution_lists} Postgres table.
 */
@Component
public class PostgresListAdapter implements ListRepositoryPort {

    private final DistributionListRepository repository;

    public PostgresListAdapter(DistributionListRepository repository) {
        this.repository = repository;
    }

    @Override
    @Transactional
    public DistributionList save(DistributionList list) {
        DistributionListEntity entity = toEntity(list);
        DistributionListEntity saved = repository.save(entity);
        return toDomain(saved);
    }

    @Override
    public Optional<DistributionList> findById(UUID listId) {
        return repository.findById(listId).map(this::toDomain);
    }

    private DistributionListEntity toEntity(DistributionList dl) {
        DistributionListEntity entity = new DistributionListEntity();
        entity.setId(dl.getId());
        entity.setName(dl.getName());
        entity.setDescription(dl.getDescription());
        entity.setExternalKey(dl.getExternalKey());
        entity.setSubscriberCount(dl.getSubscriberCount());
        entity.setCreatedAt(dl.getCreatedAt());
        return entity;
    }

    private DistributionList toDomain(DistributionListEntity e) {
        return DistributionList.builder()
                .id(e.getId())
                .name(e.getName())
                .description(e.getDescription())
                .externalKey(e.getExternalKey())
                .subscriberCount(e.getSubscriberCount())
                .createdAt(e.getCreatedAt())
                .build();
    }
}
