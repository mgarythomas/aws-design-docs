package com.example.notification.adapters.in.web;

import com.example.notification.application.ports.in.SendNotificationUseCase;
import com.example.notification.domain.Notification;
import jakarta.validation.Valid;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.stream.Collectors;

@RestController
@RequestMapping("/v1/notifications")
public class NotificationController {

    private final SendNotificationUseCase sendUseCase;

    public NotificationController(SendNotificationUseCase sendUseCase) {
        this.sendUseCase = sendUseCase;
    }

    @PostMapping
    public ResponseEntity<Map<String, String>> sendSingle(@Valid @RequestBody NotificationRequest dto) {
        Notification notification = dto.toDomain();
        String status = sendUseCase.send(notification);
        return ResponseEntity.accepted().body(Map.of(
                "notificationId", notification.getId().toString(),
                "status", status));
    }

    @PostMapping("/batch")
    public ResponseEntity<Map<String, Object>> sendBatch(@RequestBody List<NotificationRequest> requests) {
        List<Notification> notifications = requests.stream()
                .map(NotificationRequest::toDomain)
                .collect(Collectors.toList());

        List<String> statuses = sendUseCase.sendBatch(notifications);
        long accepted = statuses.stream().filter(s -> !s.startsWith("REJECTED")).count();

        return ResponseEntity.accepted().body(Map.of(
                "batchId", UUID.randomUUID().toString(),
                "acceptedCount", accepted));
    }

    /** Send a notification to all members of a distribution list. */
    @PostMapping("/list")
    public ResponseEntity<Map<String, String>> sendToList(@Valid @RequestBody ListNotificationRequest dto) {
        Notification notification = Notification.createForList(
                dto.channel(), dto.listId(), dto.source(), dto.templateId(), dto.templatePayload());
        String status = sendUseCase.sendToList(notification);
        return ResponseEntity.accepted().body(Map.of(
                "notificationId", notification.getId().toString(),
                "status", status));
    }

    // ── Request records ──────────────────────────────────────────────────────

    public record NotificationRequest(
            String channel,
            String recipientType,
            String destination,
            UUID listId,
            String source,
            String templateId,
            Map<String, Object> templatePayload) {

        public Notification toDomain() {
            if ("LIST".equalsIgnoreCase(recipientType)) {
                return Notification.createForList(channel, listId, source, templateId, templatePayload);
            }
            return Notification.createSingle(channel, destination, source, templateId, templatePayload);
        }
    }

    public record ListNotificationRequest(
            String channel,
            UUID listId,
            String source,
            String templateId,
            Map<String, Object> templatePayload) {
    }
}
