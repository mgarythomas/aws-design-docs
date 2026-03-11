package com.example.notification.adapters.in.web;

import com.example.notification.application.ports.in.SendNotificationUseCase;
import com.example.notification.domain.Notification;
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
    public ResponseEntity<Map<String, String>> sendSingleNode(@RequestBody NotificationRequest dto) {
        Notification notification = Notification.create(
                dto.channel(), dto.destination(), dto.source(), dto.templateId(), dto.templatePayload());
        String status = sendUseCase.send(notification);

        return ResponseEntity.accepted().body(Map.of(
                "notificationId", notification.getId().toString(),
                "status", status));
    }

    @PostMapping("/batch")
    public ResponseEntity<Map<String, Object>> sendBatchNodes(@RequestBody List<NotificationRequest> requests) {
        List<Notification> notifications = requests.stream()
                .map(dto -> Notification.create(dto.channel(), dto.destination(), dto.source(), dto.templateId(),
                        dto.templatePayload()))
                .collect(Collectors.toList());

        List<String> statuses = sendUseCase.sendBatch(notifications);

        long accepted = statuses.stream().filter(s -> !s.startsWith("REJECTED")).count();

        return ResponseEntity.accepted().body(Map.of(
                "batchId", UUID.randomUUID().toString(),
                "acceptedCount", accepted));
    }

    public record NotificationRequest(
            String channel,
            String destination,
            String source,
            String templateId,
            Map<String, Object> templatePayload) {
    }
}
