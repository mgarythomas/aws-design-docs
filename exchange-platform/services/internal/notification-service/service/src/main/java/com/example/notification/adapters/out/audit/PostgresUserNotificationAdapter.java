package com.example.notification.adapters.out.audit;

import com.example.notification.application.ports.out.UserNotificationPort;
import com.example.notification.domain.UserNotification;
import org.springframework.stereotype.Component;

import java.util.List;
import java.util.stream.Collectors;

@Component
public class PostgresUserNotificationAdapter implements UserNotificationPort {

    private final UserNotificationRepository repository;

    public PostgresUserNotificationAdapter(UserNotificationRepository repository) {
        this.repository = repository;
    }

    @Override
    public UserNotification save(UserNotification notification) {
        UserNotificationEntity entity = toEntity(notification);
        UserNotificationEntity saved = repository.save(entity);
        return toDomain(saved);
    }

    @Override
    public List<UserNotification> findByUserId(String userId) {
        return repository.findByUserId(userId).stream()
                .map(this::toDomain)
                .collect(Collectors.toList());
    }

    @Override
    public void delete(String userId, String notificationId) {
        repository.findByUserIdAndNotificationId(userId, notificationId)
                .ifPresent(repository::delete);
    }

    private UserNotificationEntity toEntity(UserNotification domain) {
        UserNotificationEntity entity = new UserNotificationEntity();
        entity.setNotificationId(domain.getNotificationId());
        entity.setUserId(domain.getUserId());
        entity.setMessage(domain.getMessage());
        entity.setMetadata(domain.getMetadata());
        entity.setActiveStartDate(domain.getActiveStartDate());
        entity.setActiveEndDate(domain.getActiveEndDate());
        entity.setCreatedAt(domain.getCreatedAt());
        return entity;
    }

    private UserNotification toDomain(UserNotificationEntity entity) {
        UserNotification domain = new UserNotification();
        domain.setNotificationId(entity.getNotificationId());
        domain.setUserId(entity.getUserId());
        domain.setMessage(entity.getMessage());
        domain.setMetadata(entity.getMetadata());
        domain.setActiveStartDate(entity.getActiveStartDate());
        domain.setActiveEndDate(entity.getActiveEndDate());
        domain.setCreatedAt(entity.getCreatedAt());
        return domain;
    }
}
