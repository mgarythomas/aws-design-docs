package com.example.notification.adapters.out.audit;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface UserNotificationRepository extends JpaRepository<UserNotificationEntity, String> {
    List<UserNotificationEntity> findByUserId(String userId);
    Optional<UserNotificationEntity> findByUserIdAndNotificationId(String userId, String notificationId);
}
