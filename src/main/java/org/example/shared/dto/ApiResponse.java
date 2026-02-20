package org.example.shared.dto;

import java.time.Instant;

public record ApiResponse<T>(
        boolean success,
        T data,
        ErrorResponse error,
        String requestId,
        Instant timestamp
) {
    public static <T> ApiResponse<T> success(T data, String requestId) {
        return new ApiResponse<>(true, data, null, requestId, Instant.now());
    }

    public static <T> ApiResponse<T> error(ErrorResponse error, String requestId) {
        return new ApiResponse<>(false, null, error, requestId, Instant.now());
    }
}
