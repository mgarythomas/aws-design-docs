package com.example.notification.adapters.out.audit;

import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import jakarta.persistence.Column;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;
import java.time.OffsetDateTime;
import java.util.Map;

@Entity
@Table(name = "user_notifications")
public class UserNotificationEntity {

    @Id
    @Column(name = "notification_id")
    private String notificationId;

    @Column(name = "user_id")
    private String userId;

    @Column(name = "message", length = 1000)
    private String message;

    @JdbcTypeCode(SqlTypes.JSON)
    @Column(name = "metadata", columnDefinition = "json")
    private Map<String, Object> metadata;

    @Column(name = "active_start_date")
    private OffsetDateTime activeStartDate;

    @Column(name = "active_end_date")
    private OffsetDateTime activeEndDate;

    @Column(name = "created_at")
    private OffsetDateTime createdAt;

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
