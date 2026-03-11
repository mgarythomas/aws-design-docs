package com.example.notification.simulator.config;

import org.springframework.context.annotation.Configuration;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;

@Configuration
public class SimulatorConfig {

    public static final String CSV_FILE_PATH = "simulator-logs.csv";

    public SimulatorConfig() throws IOException {
        Path path = Paths.get(CSV_FILE_PATH);
        if (!Files.exists(path)) {
            Files.writeString(path, "timestamp,channel,destination,payload,status\n");
        }
    }
}
