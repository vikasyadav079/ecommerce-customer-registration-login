package org.example.shared.dto;

import java.util.List;

public record ErrorResponse(
        String code,
        String message,
        List<ValidationError> details
) {
    public ErrorResponse(String code, String message) {
        this(code, message, List.of());
    }
}
