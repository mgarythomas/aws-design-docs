package com.det.exchange.validation.service;

import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestClient;
import software.amazon.awssdk.services.s3.S3Client;
import software.amazon.awssdk.services.s3.model.ListObjectsV2Request;
import software.amazon.awssdk.services.s3.model.ListObjectsV2Response;
import software.amazon.awssdk.services.s3.model.S3Object;

import jakarta.annotation.PostConstruct;
import java.nio.charset.StandardCharsets;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

@Service
@Slf4j
public class S3PolicyLoaderService {

    private final S3Client s3Client;
    private final RestClient restClient;
    private final String bucketName;
    private final String opaUrl;

    // Cache ETags to prevent unnecessary pushes to OPA sidecar
    private final Map<String, String> policyEtagCache = new ConcurrentHashMap<>();

    public S3PolicyLoaderService(
            S3Client s3Client,
            RestClient.Builder restClientBuilder,
            @Value("${s3.bucket.policies:det-exchange-policies}") String bucketName,
            @Value("${opa.url:http://localhost:8181}") String opaUrl) {
        this.s3Client = s3Client;
        this.restClient = restClientBuilder.build();
        this.bucketName = bucketName;
        this.opaUrl = opaUrl;
    }

    @PostConstruct
    public void init() {
        log.info("S3 Policy Loader initialized. Will load policies from bucket: {}", bucketName);
        try {
            loadPoliciesFromS3();
        } catch (Exception e) {
            log.warn("Initial policy load failed, will retry on schedule. Error: {}", e.getMessage());
        }
    }

    @Scheduled(fixedRateString = "${policy.refresh.rate:60000}")
    public void scheduledLoad() {
        try {
            loadPoliciesFromS3();
        } catch (Exception e) {
            log.error("Scheduled policy load failed", e);
        }
    }

    private void loadPoliciesFromS3() {
        log.debug("Checking for policy updates from S3 bucket: {}", bucketName);

        ListObjectsV2Request listReq = ListObjectsV2Request.builder()
                .bucket(bucketName)
                .build();

        ListObjectsV2Response listRes = s3Client.listObjectsV2(listReq);

        for (S3Object s3Object : listRes.contents()) {
            if (s3Object.key().endsWith(".rego")) {
                String key = s3Object.key();
                String currentETag = s3Object.eTag();

                if (!currentETag.equals(policyEtagCache.get(key))) {
                    log.info("Detected new/updated policy: {}. Fetching from S3.", key);
                    String policyId = extractPolicyId(key);
                    String policyContent = fetchPolicyContent(key);
                    pushPolicyToOpa(policyId, policyContent);
                    policyEtagCache.put(key, currentETag);
                }
            }
        }
    }

    private String fetchPolicyContent(String key) {
        try {
            return new String(s3Client.getObject(b -> b.bucket(bucketName).key(key)).readAllBytes(),
                    StandardCharsets.UTF_8);
        } catch (java.io.IOException e) {
            log.error("Failed to read policy content for key: {}", key, e);
            throw new RuntimeException("Error reading policy from S3", e);
        }
    }

    private String extractPolicyId(String key) {
        // e.g., "policies/corporate_action.rego" -> "corporate_action"
        String name = key.contains("/") ? key.substring(key.lastIndexOf("/") + 1) : key;
        return name.replace(".rego", "");
    }

    private void pushPolicyToOpa(String policyId, String content) {
        String url = opaUrl + (opaUrl.endsWith("/") ? "" : "/") + "v1/policies/" + policyId;
        log.debug("Pushing policy {} to OPA sidecar at {}", policyId, url);

        try {
            restClient.put()
                    .uri(url)
                    .header("Content-Type", "text/plain")
                    .body(content)
                    .retrieve()
                    .toBodilessEntity();
            log.info("Successfully pushed policy {} to OPA.", policyId);
        } catch (Exception e) {
            log.error("Failed to push policy {} to OPA. Removing from ETag cache to retry next cycle.", policyId, e);
            throw e;
        }
    }
}
