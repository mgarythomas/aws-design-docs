package com.example.notification.domain.service;

import com.example.notification.application.ports.out.UserNotificationPort;
import com.example.notification.domain.UserNotification;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.Mock;
import org.mockito.MockitoAnnotations;

import java.time.OffsetDateTime;
import java.util.Arrays;
import java.util.List;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

class UserNotificationDomainServiceTest {

    @Mock
    private UserNotificationPort userNotificationPort;

    private UserNotificationDomainService service;

    @BeforeEach
    void setUp() {
        MockitoAnnotations.openMocks(this);
        service = new UserNotificationDomainService(userNotificationPort);
    }

    @Test
    void shouldCreateUserNotification() {
        // Given
        UserNotification input = new UserNotification();
        input.setUserId("user-123");
        input.setMessage("Test message");
        input.setActiveStartDate(OffsetDateTime.now());

        UserNotification saved = new UserNotification();
        saved.setNotificationId("generated-uuid");
        saved.setUserId("user-123");
        saved.setMessage("Test message");

        when(userNotificationPort.save(any(UserNotification.class))).thenReturn(saved);

        // When
        UserNotification result = service.createUserNotification(input);

        // Then
        assertNotNull(result);
        assertEquals("generated-uuid", result.getNotificationId());
        assertEquals("user-123", result.getUserId());

        verify(userNotificationPort, times(1)).save(any(UserNotification.class));
    }

    @Test
    void shouldGetUserNotifications() {
        // Given
        UserNotification notification = new UserNotification();
        notification.setNotificationId("id-1");
        notification.setUserId("user-123");

        when(userNotificationPort.findByUserId("user-123")).thenReturn(Arrays.asList(notification));

        // When
        List<UserNotification> results = service.getUserNotifications("user-123");

        // Then
        assertFalse(results.isEmpty());
        assertEquals(1, results.size());
        assertEquals("id-1", results.get(0).getNotificationId());

        verify(userNotificationPort, times(1)).findByUserId("user-123");
    }

    @Test
    void shouldDeleteUserNotification() {
        // Given
        String userId = "user-123";
        String notificationId = "notif-456";

        // When
        service.deleteUserNotification(userId, notificationId);

        // Then
        verify(userNotificationPort, times(1)).delete(userId, notificationId);
    }
}
