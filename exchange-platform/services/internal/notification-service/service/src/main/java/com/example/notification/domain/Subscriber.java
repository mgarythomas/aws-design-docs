package com.example.notification.domain;

import lombok.Builder;
import lombok.Getter;

import java.util.Map;

/**
 * Domain value object representing a subscriber on a distribution list.
 * The {@code attributes} map allows arbitrary SFMC Data Extension column values
 * to be passed through without polluting the domain model.
 */
@Getter
@Builder
public class Subscriber {

    private final String subscriberId;
    private final String email;
    private final String firstName;
    private final String lastName;
    private final Map<String, Object> attributes;
}
