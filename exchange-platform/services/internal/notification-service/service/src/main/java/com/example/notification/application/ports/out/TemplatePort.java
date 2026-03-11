package com.example.notification.application.ports.out;

import java.util.Map;

public interface TemplatePort {
    String render(String templateId, Map<String, Object> payload);
}
