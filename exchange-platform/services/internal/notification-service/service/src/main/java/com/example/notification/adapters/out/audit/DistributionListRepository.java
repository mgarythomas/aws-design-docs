package com.example.notification.adapters.out.audit;

import org.springframework.data.jpa.repository.JpaRepository;

import java.util.UUID;

public interface DistributionListRepository extends JpaRepository<DistributionListEntity, UUID> {
}
