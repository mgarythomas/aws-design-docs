package com.example.notification.config;

import dev.openfeature.sdk.OpenFeatureAPI;
import dev.openfeature.sdk.providers.memory.InMemoryProvider;
import dev.openfeature.sdk.providers.memory.Flag;
import org.springframework.context.annotation.Configuration;

import jakarta.annotation.PostConstruct;
import java.util.HashMap;
import java.util.Map;

@Configuration
public class OpenFeatureConfig {

    @PostConstruct
    public void setupOpenFeature() {
        Map<String, Flag<?>> flags = new HashMap<>();

        // Setup default OpenFeature flags allowing the base EMAIL channel to succeed.
        flags.put("channel-email-enabled", Flag.builder().variant("on", true).defaultVariant("on").build());
        flags.put("channel-sms-enabled", Flag.builder().variant("off", false).defaultVariant("off").build());

        InMemoryProvider provider = new InMemoryProvider(flags);
        OpenFeatureAPI.getInstance().setProviderAndWait(provider);
    }
}
