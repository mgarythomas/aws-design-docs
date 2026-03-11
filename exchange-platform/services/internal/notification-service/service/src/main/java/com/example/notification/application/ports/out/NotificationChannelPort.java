package com.example.notification.application.ports.out;

import com.example.notification.domain.Notification;

public interface NotificationChannelPort {
    boolean supports(String channel);

    String dispatch(Notification notification, String renderedContent);
}
