package com.example.notification.domain;

import java.time.OffsetDateTime;
import java.util.Map;

public class UserNotification {
    private String notificationId;
    private String userId;
    private String message;
    private Map<String, Object> metadata;
    private OffsetDateTime activeStartDate;
    private OffsetDateTime activeEndDate;
    private OffsetDateTime createdAt;

    // Default constructor
    public UserNotification() {
    }

    // Getters and Setters
    public String getNotificationId() {
        return notificationId;
    }

    public void setNotificationId(String notificationId) {
        this.notificationId = notificationId;
    }

    public String getUserId() {
        return userId;
    }

    public void setUserId(String userId) {
        this.userId = userId;
    }

    public String getMessage() {
        return message;
    }

    public void setMessage(String message) {
        this.message = message;
    }

    public Map<String, Object> getMetadata() {
        return metadata;
    }

    public void setMetadata(Map<String, Object> metadata) {
        this.metadata = metadata;
    }

    public OffsetDateTime getActiveStartDate() {
        return activeStartDate;
    }

    public void setActiveStartDate(OffsetDateTime activeStartDate) {
        this.activeStartDate = activeStartDate;
    }

    public OffsetDateTime getActiveEndDate() {
        return activeEndDate;
    }

    public void setActiveEndDate(OffsetDateTime activeEndDate) {
        this.activeEndDate = activeEndDate;
    }

    public OffsetDateTime getCreatedAt() {
        return createdAt;
    }

    public void setCreatedAt(OffsetDateTime createdAt) {
        this.createdAt = createdAt;
    }
}
