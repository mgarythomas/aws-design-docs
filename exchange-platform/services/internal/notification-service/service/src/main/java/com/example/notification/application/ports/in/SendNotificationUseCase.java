package com.example.notification.application.ports.in;

import com.example.notification.domain.Notification;
import java.util.List;

public interface SendNotificationUseCase {
    String send(Notification notification);

    List<String> sendBatch(List<Notification> notifications);
}
