package com.example.notification.adapters.out.salesforce;

import com.example.notification.application.ports.out.NotificationChannelPort;
import com.example.notification.domain.Notification;
import org.springframework.stereotype.Component;
import org.springframework.web.client.RestTemplate;
import org.springframework.http.ResponseEntity;

import java.util.Map;

@Component
public class SalesforceEmailAdapter implements NotificationChannelPort {

    private final RestTemplate restTemplate = new RestTemplate();
    private final String simulatorEndpoint = "http://localhost:8081/api/simulator/mock/email";

    @Override
    public boolean supports(String channel) {
        return "EMAIL".equalsIgnoreCase(channel);
    }

    @Override
    public String dispatch(Notification notification, String renderedContent) {
        // Adapt domain logic into Salesforce specific JSON contract (targeting
        // Simulator)
        Map<String, Object> requestBody = Map.of(
                "to", notification.getDestination(),
                "subject", "Notification from " + notification.getSource(),
                "body", renderedContent);

        try {
            ResponseEntity<Map> response = restTemplate.postForEntity(simulatorEndpoint, requestBody, Map.class);
            if (response.getStatusCode().is2xxSuccessful()) {
                return "DELIVERED";
            }
            return "FAILED_VENDOR_REJECTED";
        } catch (Exception e) {
            return "FAILED_NETWORK";
        }
    }
}
