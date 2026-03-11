package com.example.notification.application.ports.in;

import com.example.notification.domain.UserNotification;
import java.util.List;

public interface UserNotificationUseCase {
    UserNotification createUserNotification(UserNotification notification);
    List<UserNotification> getUserNotifications(String userId);
    void deleteUserNotification(String userId, String notificationId);
}
