package com.example.notification.domain.service;

import com.example.notification.application.ports.in.SendNotificationUseCase;
import com.example.notification.application.ports.out.AuditPort;
import com.example.notification.application.ports.out.ListRepositoryPort;
import com.example.notification.application.ports.out.NotificationChannelPort;
import com.example.notification.application.ports.out.TemplatePort;
import com.example.notification.domain.DistributionList;
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
    private final ListRepositoryPort listRepositoryPort;
    private final Client featureClient;

    public NotificationDomainService(List<NotificationChannelPort> channels,
            TemplatePort templatePort,
            AuditPort auditPort,
            ListRepositoryPort listRepositoryPort) {
        this.channels = channels;
        this.templatePort = templatePort;
        this.auditPort = auditPort;
        this.listRepositoryPort = listRepositoryPort;
        this.featureClient = OpenFeatureAPI.getInstance().getClient();
    }

    @Override
    public String send(Notification notification) {
        boolean channelEnabled = featureClient
                .getBooleanValue("channel-" + notification.getChannel().toLowerCase() + "-enabled", true);
        if (!channelEnabled) {
            auditPort.recordAudit(notification, "REJECTED_FEATURE_FLAG");
            return "REJECTED";
        }

        String renderedContent = templatePort.render(notification.getTemplateId(), notification.getTemplatePayload());

        try {
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

    /**
     * Resolves a list-targeted notification by looking up the {@link DistributionList}
     * and delegating to the channel adapter. The {@code externalKey} (SFMC DataExtensionKey)
     * is attached to the notification so the adapter can target the correct Data Extension.
     */
    @Override
    public String sendToList(Notification notification) {
        DistributionList list = listRepositoryPort.findById(notification.getListId())
                .orElseThrow(() -> new IllegalArgumentException(
                        "Distribution list not found: " + notification.getListId()));

        boolean channelEnabled = featureClient
                .getBooleanValue("channel-" + notification.getChannel().toLowerCase() + "-enabled", true);
        if (!channelEnabled) {
            auditPort.recordAudit(notification, "REJECTED_FEATURE_FLAG");
            return "REJECTED";
        }

        String renderedContent = templatePort.render(notification.getTemplateId(), notification.getTemplatePayload());

        try {
            NotificationChannelPort activePort = channels.stream()
                    .filter(port -> port.supports(notification.getChannel()))
                    .findFirst()
                    .orElseThrow(
                            () -> new IllegalArgumentException("Unsupported channel: " + notification.getChannel()));

            // Rebuild notification with the resolved externalKey so the adapter can address the list
            Notification enriched = Notification.builder()
                    .id(notification.getId())
                    .channel(notification.getChannel())
                    .recipientType(Notification.RecipientType.LIST)
                    .listId(notification.getListId())
                    .source(notification.getSource())
                    .templateId(notification.getTemplateId())
                    .templatePayload(notification.getTemplatePayload())
                    // Temporarily carry the externalKey in destination so existing dispatch contract is satisfied
                    .destination(list.getExternalKey())
                    .build();

            String dispatchStatus = activePort.dispatch(enriched, renderedContent);
            auditPort.recordAudit(notification, dispatchStatus);
            return dispatchStatus;
        } catch (Exception e) {
            auditPort.recordAudit(notification, "FAILED");
            throw e;
        }
    }
}
