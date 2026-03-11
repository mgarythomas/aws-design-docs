package com.example.notification.adapters.out.audit;

import com.example.notification.application.ports.out.AuditPort;
import com.example.notification.domain.Notification;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

@Component
public class PostgresAuditAdapter implements AuditPort {

    private final AuditRepository repository;

    public PostgresAuditAdapter(AuditRepository repository) {
        this.repository = repository;
    }

    @Override
    @Transactional
    public void recordAudit(Notification notification, String dispatcherStatus) {
        AuditEntity entity = new AuditEntity();
        entity.setNotificationId(notification.getId());
        entity.setChannel(notification.getChannel());
        entity.setSource(notification.getSource());
        entity.setDestination(notification.getDestination());
        entity.setStatus(dispatcherStatus);

        repository.save(entity);
    }
}
