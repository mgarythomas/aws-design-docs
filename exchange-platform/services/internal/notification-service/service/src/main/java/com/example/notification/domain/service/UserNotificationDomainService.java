package com.example.notification.domain.service;

import com.example.notification.application.ports.in.UserNotificationUseCase;
import com.example.notification.application.ports.out.UserNotificationPort;
import com.example.notification.domain.UserNotification;
import org.springframework.stereotype.Service;

import java.time.OffsetDateTime;
import java.util.List;
import java.util.UUID;

@Service
public class UserNotificationDomainService implements UserNotificationUseCase {

    private final UserNotificationPort userNotificationPort;

    public UserNotificationDomainService(UserNotificationPort userNotificationPort) {
        this.userNotificationPort = userNotificationPort;
    }

    @Override
    public UserNotification createUserNotification(UserNotification notification) {
        notification.setNotificationId(UUID.randomUUID().toString());
        notification.setCreatedAt(OffsetDateTime.now());
        return userNotificationPort.save(notification);
    }

    @Override
    public List<UserNotification> getUserNotifications(String userId) {
        return userNotificationPort.findByUserId(userId);
    }

    @Override
    public void deleteUserNotification(String userId, String notificationId) {
        userNotificationPort.delete(userId, notificationId);
    }
}
