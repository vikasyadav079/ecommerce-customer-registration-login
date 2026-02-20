package org.example.shared.dto;

public record ValidationError(
        String field,
        String message,
        Object rejectedValue
) {}
