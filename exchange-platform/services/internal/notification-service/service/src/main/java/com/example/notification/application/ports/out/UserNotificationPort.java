package com.example.notification.application.ports.out;

import com.example.notification.domain.UserNotification;
import java.util.List;

public interface UserNotificationPort {
    UserNotification save(UserNotification notification);
    List<UserNotification> findByUserId(String userId);
    void delete(String userId, String notificationId);
}
