package com.example.notification.domain.service;

import com.example.notification.application.ports.in.SendNotificationUseCase;
import com.example.notification.application.ports.out.AuditPort;
import com.example.notification.application.ports.out.NotificationChannelPort;
import com.example.notification.application.ports.out.TemplatePort;
import com.example.notification.domain.Notification;
import dev.openfeature.sdk.Client;
import dev.openfeature.sdk.OpenFeatureAPI;
import org.springframework.stereotype.Service;

import java.util.List;
import java.util.stream.Collectors;

@Service
public class NotificationDomainService implements SendNotificationUseCase {

    private final List<NotificationChannelPort> channels;
    private final TemplatePort templatePort;
    private final AuditPort auditPort;
    private final Client featureClient;

    public NotificationDomainService(List<NotificationChannelPort> channels,
            TemplatePort templatePort,
            AuditPort auditPort) {
        this.channels = channels;
        this.templatePort = templatePort;
        this.auditPort = auditPort;
        this.featureClient = OpenFeatureAPI.getInstance().getClient();
    }

    @Override
    public String send(Notification notification) {
        // Feature flag validation: is channel enabled system-wide?
        boolean channelEnabled = featureClient
                .getBooleanValue("channel-" + notification.getChannel().toLowerCase() + "-enabled", true);
        if (!channelEnabled) {
            auditPort.recordAudit(notification, "REJECTED_FEATURE_FLAG");
            return "REJECTED";
        }

        // Render template Content
        String renderedContent = templatePort.render(notification.getTemplateId(), notification.getTemplatePayload());

        try {
            // Find applicable delivery port based on strategy
            NotificationChannelPort activePort = channels.stream()
                    .filter(port -> port.supports(notification.getChannel()))
                    .findFirst()
                    .orElseThrow(
                            () -> new IllegalArgumentException("Unsupported channel: " + notification.getChannel()));

            String dispatchStatus = activePort.dispatch(notification, renderedContent);
            auditPort.recordAudit(notification, dispatchStatus);
            return dispatchStatus;
        } catch (Exception e) {
            auditPort.recordAudit(notification, "FAILED");
            throw e;
        }
    }

    @Override
    public List<String> sendBatch(List<Notification> notifications) {
        return notifications.stream()
                .map(this::send)
                .collect(Collectors.toList());
    }
}
