package com.example.notification.adapters.out.salesforce;

import com.example.notification.application.ports.out.ListProviderPort;
import com.example.notification.domain.Subscriber;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.MediaType;
import org.springframework.stereotype.Component;
import org.springframework.web.client.RestClient;

import java.util.HashMap;
import java.util.Map;

/**
 * Secondary adapter implementing {@link ListProviderPort} via the SFMC Data Extensions API.
 * Authenticates using OAuth 2.0 bearer tokens provided by {@link SfmcTokenService}.
 *
 * <p>Each distribution list maps 1-to-1 with an SFMC Data Extension.
 * The {@code DataExtensionKey} returned from creation is stored by the domain
 * as the {@code externalKey} on the {@link com.example.notification.domain.DistributionList}.
 */
@Component
public class SfmcListManagementAdapter implements ListProviderPort {

    private final RestClient restClient;
    private final SfmcTokenService tokenService;
    private final String sfmcBaseUrl;

    public SfmcListManagementAdapter(
            SfmcTokenService tokenService,
            @Value("${sfmc.base-url}") String sfmcBaseUrl) {
        this.tokenService = tokenService;
        this.sfmcBaseUrl = sfmcBaseUrl;
        this.restClient = RestClient.create();
    }

    @Override
    public String createList(String name) {
        String token = tokenService.getBearerToken();

        Map<String, Object> body = Map.of(
                "name", name,
                "customerKey", name.replaceAll("\\s+", "_").toLowerCase(),
                "fields", java.util.List.of(
                        fieldDef("subscriberId", "Text", false),
                        fieldDef("email", "EmailAddress", true),
                        fieldDef("firstName", "Text", false),
                        fieldDef("lastName", "Text", false)));

        @SuppressWarnings("unchecked")
        Map<String, Object> response = restClient.post()
                .uri(sfmcBaseUrl + "/data/v1/customobjectdata/key/DataExtension/rowset")
                .header("Authorization", "Bearer " + token)
                .contentType(MediaType.APPLICATION_JSON)
                .body(body)
                .retrieve()
                .body(Map.class);

        // Return the customerKey (DataExtensionKey) assigned by SFMC
        return response != null ? (String) response.get("customerKey") : name;
    }

    @Override
    public void addSubscriber(String externalKey, Subscriber subscriber) {
        String token = tokenService.getBearerToken();

        Map<String, Object> row = new HashMap<>();
        row.put("subscriberId", subscriber.getSubscriberId());
        row.put("email", subscriber.getEmail());
        row.put("firstName", subscriber.getFirstName());
        row.put("lastName", subscriber.getLastName());
        if (subscriber.getAttributes() != null) {
            row.putAll(subscriber.getAttributes());
        }

        restClient.post()
                .uri(sfmcBaseUrl + "/data/v1/customobjectdata/key/" + externalKey + "/rowset")
                .header("Authorization", "Bearer " + token)
                .contentType(MediaType.APPLICATION_JSON)
                .body(Map.of("items", java.util.List.of(row)))
                .retrieve()
                .toBodilessEntity();
    }

    @Override
    public void removeSubscriber(String externalKey, String subscriberId) {
        String token = tokenService.getBearerToken();

        restClient.delete()
                .uri(sfmcBaseUrl + "/data/v1/customobjectdata/key/" + externalKey
                        + "/rowset?$filter=subscriberId eq '" + subscriberId + "'")
                .header("Authorization", "Bearer " + token)
                .retrieve()
                .toBodilessEntity();
    }

    private Map<String, Object> fieldDef(String name, String type, boolean primaryKey) {
        return Map.of("name", name, "fieldType", type, "isPrimaryKey", primaryKey, "isRequired", primaryKey);
    }
}
