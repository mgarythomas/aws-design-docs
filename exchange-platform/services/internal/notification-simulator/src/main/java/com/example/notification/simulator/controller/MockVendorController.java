package com.example.notification.simulator.controller;

import com.example.notification.simulator.domain.NotificationLog;
import com.example.notification.simulator.service.LogService;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.time.Instant;
import java.util.List;
import java.util.Map;
import java.util.UUID;

@RestController
@RequestMapping("/api/simulator")
public class MockVendorController {

    private final LogService logService;

    public MockVendorController(LogService logService) {
        this.logService = logService;
    }

    /**
     * Represents a mock external vendor receiving an email send request.
     */
    @PostMapping("/mock/email")
    public ResponseEntity<Map<String, String>> mockSendEmail(@RequestBody Map<String, Object> payload) {
        logService.appendLog(NotificationLog.builder()
                .timestamp(Instant.now())
                .channel("EMAIL")
                .destination((String) payload.getOrDefault("to", "unknown"))
                .payload(payload.toString())
                .status("ACCEPTED")
                .build());

        return ResponseEntity.ok(Map.of(
                "messageId", UUID.randomUUID().toString(),
                "status", "simulated-success"));
    }

    /**
     * Dynamic DuckDb query route to assert test results
     */
    @PostMapping("/query")
    public ResponseEntity<List<Map<String, Object>>> querySimulator(@RequestBody Map<String, String> queryRequest) {
        String sql = queryRequest.get("sql");
        if (sql == null || sql.isBlank()) {
            return ResponseEntity.badRequest().build();
        }
        return ResponseEntity.ok(logService.queryLogs(sql));
    }
}
