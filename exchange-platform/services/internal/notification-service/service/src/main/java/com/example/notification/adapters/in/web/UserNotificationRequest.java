package com.example.notification.adapters.in.web;

import java.time.OffsetDateTime;
import java.util.Map;

public class UserNotificationRequest {
    private String message;
    private Map<String, Object> metadata;
    private OffsetDateTime activeStartDate;
    private OffsetDateTime activeEndDate;

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
}
