package com.example.notification.adapters.in.web;

import com.example.notification.application.ports.in.UserNotificationUseCase;
import com.example.notification.domain.UserNotification;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/users/{userId}/notifications")
public class UserNotificationController {

    private final UserNotificationUseCase userNotificationUseCase;

    public UserNotificationController(UserNotificationUseCase userNotificationUseCase) {
        this.userNotificationUseCase = userNotificationUseCase;
    }

    @PostMapping
    public ResponseEntity<UserNotification> createUserNotification(
            @PathVariable String userId,
            @RequestBody UserNotificationRequest request) {

        UserNotification domain = new UserNotification();
        domain.setUserId(userId);
        domain.setMessage(request.getMessage());
        domain.setMetadata(request.getMetadata());
        domain.setActiveStartDate(request.getActiveStartDate());
        domain.setActiveEndDate(request.getActiveEndDate());

        UserNotification created = userNotificationUseCase.createUserNotification(domain);

        return ResponseEntity.status(HttpStatus.CREATED).body(created);
    }

    @GetMapping
    public ResponseEntity<List<UserNotification>> getUserNotifications(@PathVariable String userId) {
        List<UserNotification> notifications = userNotificationUseCase.getUserNotifications(userId);
        return ResponseEntity.ok(notifications);
    }

    @DeleteMapping("/{notificationId}")
    public ResponseEntity<Void> deleteUserNotification(
            @PathVariable String userId,
            @PathVariable String notificationId) {

        userNotificationUseCase.deleteUserNotification(userId, notificationId);
        return ResponseEntity.noContent().build();
    }
}
