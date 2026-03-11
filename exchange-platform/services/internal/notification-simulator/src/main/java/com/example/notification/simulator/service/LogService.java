package com.example.notification.simulator.service;

import com.example.notification.simulator.config.SimulatorConfig;
import com.example.notification.simulator.domain.NotificationLog;
import com.opencsv.CSVWriter;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;

import java.io.FileWriter;
import java.io.IOException;
import java.util.List;
import java.util.Map;

@Service
public class LogService {

    private final JdbcTemplate duckDbJdbcTemplate;

    public LogService(JdbcTemplate duckDbJdbcTemplate) {
        this.duckDbJdbcTemplate = duckDbJdbcTemplate;
        initDuckDbView();
    }

    private void initDuckDbView() {
        // Create a DuckDB view mapping directly to the CSV file
        duckDbJdbcTemplate.execute(
                "CREATE VIEW IF NOT EXISTS logs AS SELECT * FROM read_csv_auto('" + SimulatorConfig.CSV_FILE_PATH
                        + "')");
    }

    public void appendLog(NotificationLog log) {
        try (CSVWriter writer = new CSVWriter(new FileWriter(SimulatorConfig.CSV_FILE_PATH, true))) {
            String[] record = {
                    log.getTimestamp().toString(),
                    log.getChannel(),
                    log.getDestination(),
                    log.getPayload(),
                    log.getStatus()
            };
            writer.writeNext(record, false);
        } catch (IOException e) {
            throw new RuntimeException("Failed to write to simulator log CSV", e);
        }
    }

    public List<Map<String, Object>> queryLogs(String sql) {
        // Caution in production, but acceptable for a dedicated test simulator query
        // layer
        return duckDbJdbcTemplate.queryForList(sql);
    }
}
