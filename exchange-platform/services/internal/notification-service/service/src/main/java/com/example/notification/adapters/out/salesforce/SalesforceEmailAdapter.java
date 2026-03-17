package com.example.notification.adapters.out.salesforce;

import com.example.notification.application.ports.out.NotificationChannelPort;
import com.example.notification.domain.Notification;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.MediaType;
import org.springframework.stereotype.Component;
import org.springframework.web.client.RestClient;

import java.util.Map;

/**
 * Secondary adapter implementing {@link NotificationChannelPort} for email delivery via SFMC.
 *
 * <p>Authenticates using OAuth 2.0 bearer tokens provided by {@link SfmcTokenService}.
 * For {@code SINGLE} recipient types, sends to the {@code destination} address.
 * For {@code LIST} recipient types, the {@code destination} field carries the resolved
 * SFMC DataExtensionKey and triggers a list-wide Triggered Send.
 */
@Component
public class SalesforceEmailAdapter implements NotificationChannelPort {

    private final RestClient restClient;
    private final SfmcTokenService tokenService;
    private final String sfmcBaseUrl;

    public SalesforceEmailAdapter(
            SfmcTokenService tokenService,
            @Value("${sfmc.base-url}") String sfmcBaseUrl) {
        this.tokenService = tokenService;
        this.sfmcBaseUrl = sfmcBaseUrl;
        this.restClient = RestClient.create();
    }

    @Override
    public boolean supports(String channel) {
        return "EMAIL".equalsIgnoreCase(channel);
    }

    @Override
    public String dispatch(Notification notification, String renderedContent) {
        try {
            boolean isList = notification.getRecipientType() == Notification.RecipientType.LIST;
            String token = tokenService.getBearerToken();

            Map<String, Object> requestBody = isList
                    ? buildListSendPayload(notification, renderedContent)
                    : buildSingleSendPayload(notification, renderedContent);

            String endpoint = isList
                    ? sfmcBaseUrl + "/messaging/v1/email/messages/list"
                    : sfmcBaseUrl + "/messaging/v1/email/messages";

            var response = restClient.post()
                    .uri(endpoint)
                    .header("Authorization", "Bearer " + token)
                    .contentType(MediaType.APPLICATION_JSON)
                    .body(requestBody)
                    .retrieve()
                    .toBodilessEntity();

            return response.getStatusCode().is2xxSuccessful() ? "DELIVERED" : "FAILED_VENDOR_REJECTED";
        } catch (Exception e) {
            return "FAILED_NETWORK";
        }
    }

    private Map<String, Object> buildSingleSendPayload(Notification n, String renderedContent) {
        return Map.of(
                "definitionKey", n.getTemplateId(),
                "recipients", java.util.List.of(Map.of(
                        "address", n.getDestination(),
                        "attributes", n.getTemplatePayload() != null ? n.getTemplatePayload() : Map.of())),
                "content", Map.of("message", renderedContent));
    }

    private Map<String, Object> buildListSendPayload(Notification n, String renderedContent) {
        // destination carries the resolved SFMC DataExtensionKey for list sends
        return Map.of(
                "definitionKey", n.getTemplateId(),
                "dataExtensionKey", n.getDestination(),
                "content", Map.of("message", renderedContent));
    }
}
