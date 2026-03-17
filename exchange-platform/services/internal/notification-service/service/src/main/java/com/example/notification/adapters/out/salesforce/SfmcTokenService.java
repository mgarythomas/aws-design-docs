package com.example.notification.adapters.out.salesforce;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.MediaType;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestClient;

import java.time.Instant;
import java.util.Map;
import java.util.concurrent.atomic.AtomicReference;

/**
 * Fetches and caches OAuth 2.0 bearer tokens from SFMC using the
 * {@code client_credentials} grant type. Tokens are cached in-memory
 * and re-fetched automatically when they expire.
 *
 * <p>Credentials are injected from the environment (populated by
 * AWS Secrets Manager / External Secrets Operator on EKS).
 */
@Service
public class SfmcTokenService {

    private final RestClient restClient;
    private final String authUrl;
    private final String clientId;
    private final String clientSecret;

    private final AtomicReference<CachedToken> tokenCache = new AtomicReference<>();

    public SfmcTokenService(
            @Value("${sfmc.auth-url}") String authUrl,
            @Value("${sfmc.client-id}") String clientId,
            @Value("${sfmc.client-secret}") String clientSecret) {
        this.authUrl = authUrl;
        this.clientId = clientId;
        this.clientSecret = clientSecret;
        this.restClient = RestClient.create();
    }

    /**
     * Returns a valid OAuth 2.0 bearer token, fetching a new one if the
     * cached token has expired or is not yet set.
     */
    public String getBearerToken() {
        CachedToken cached = tokenCache.get();
        if (cached != null && !cached.isExpired()) {
            return cached.accessToken();
        }
        return fetchAndCacheToken();
    }

    @SuppressWarnings("unchecked")
    private synchronized String fetchAndCacheToken() {
        // Double-checked: another thread may have already refreshed it
        CachedToken cached = tokenCache.get();
        if (cached != null && !cached.isExpired()) {
            return cached.accessToken();
        }

        Map<String, String> body = Map.of(
                "grant_type", "client_credentials",
                "client_id", clientId,
                "client_secret", clientSecret);

        Map<String, Object> response = restClient.post()
                .uri(authUrl + "/v2/token")
                .contentType(MediaType.APPLICATION_JSON)
                .body(body)
                .retrieve()
                .body(Map.class);

        String accessToken = (String) response.get("access_token");
        int expiresIn = ((Number) response.get("expires_in")).intValue();

        // Store token with a 30-second buffer before the reported expiry
        tokenCache.set(new CachedToken(accessToken, Instant.now().plusSeconds(expiresIn - 30)));
        return accessToken;
    }

    private record CachedToken(String accessToken, Instant expiresAt) {
        boolean isExpired() {
            return Instant.now().isAfter(expiresAt);
        }
    }
}
