package com.example.notification.application.ports.in;

import com.example.notification.domain.Notification;

import java.util.List;

public interface SendNotificationUseCase {

    String send(Notification notification);

    List<String> sendBatch(List<Notification> notifications);

    /**
     * Dispatches a notification to all members of the referenced distribution list.
     * The domain resolves the {@code listId} via the {@link ListProviderPort} and
     * triggers delivery through the appropriate channel adapter.
     */
    String sendToList(Notification notification);
}
