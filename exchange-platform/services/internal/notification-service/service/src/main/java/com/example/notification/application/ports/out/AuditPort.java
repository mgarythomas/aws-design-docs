package com.example.notification.application.ports.out;

import com.example.notification.domain.Notification;

public interface AuditPort {
    void recordAudit(Notification notification, String dispatcherStatus);
}
