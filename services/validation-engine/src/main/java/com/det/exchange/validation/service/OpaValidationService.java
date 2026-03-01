package com.det.exchange.validation.service;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestClient;

import java.util.Map;

@Service
@Slf4j
public class OpaValidationService {

    private final RestClient restClient;
    private final ObjectMapper objectMapper;
    private final String opaUrl;

    public OpaValidationService(
            RestClient.Builder restClientBuilder,
            ObjectMapper objectMapper,
            @Value("${opa.url:http://localhost:8181}") String opaUrl) {
        this.restClient = restClientBuilder.build();
        this.objectMapper = objectMapper;
        this.opaUrl = opaUrl;
    }

    public JsonNode validateDocument(JsonNode document) {
        return callOpa("/v1/data/corporate_action/document", document);
    }

    public JsonNode validateField(JsonNode fieldRequest) {
        return callOpa("/v1/data/corporate_action/field", fieldRequest);
    }

    private JsonNode callOpa(String policyPath, JsonNode payload) {
        try {
            var requestBody = Map.of("input", payload);
            String url = opaqueUrl(opaUrl, policyPath);
            log.debug("Calling OPA at URL: {}", url);

            JsonNode response = restClient.post()
                    .uri(url)
                    .body(requestBody)
                    .retrieve()
                    .body(JsonNode.class);

            if (response != null && response.has("result")) {
                return response.get("result");
            }
            return response;
        } catch (Exception e) {
            log.error("Error communicating with OPA sidecar: ", e);
            throw new RuntimeException("Validation Engine Error: Unable to evaluate policy", e);
        }
    }

    private String opaqueUrl(String base, String path) {
        if (base.endsWith("/") && path.startsWith("/")) {
            return base + path.substring(1);
        } else if (!base.endsWith("/") && !path.startsWith("/")) {
            return base + "/" + path;
        }
        return base + path;
    }
}
