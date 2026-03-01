package com.det.exchange.validation;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.scheduling.annotation.EnableScheduling;

@SpringBootApplication
@EnableScheduling
public class ValidationEngineApplication {

	public static void main(String[] args) {
		SpringApplication.run(ValidationEngineApplication.class, args);
	}

}
