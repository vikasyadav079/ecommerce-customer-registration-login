package org.example.shared.exception;

import org.springframework.http.HttpStatus;

public enum ErrorCode {

    // Authentication errors
    AUTH_001("AUTH-001", "Invalid credentials", HttpStatus.UNAUTHORIZED),
    AUTH_002("AUTH-002", "Account locked", HttpStatus.LOCKED),
    AUTH_003("AUTH-003", "Account not verified", HttpStatus.FORBIDDEN),
    AUTH_004("AUTH-004", "Token expired", HttpStatus.UNAUTHORIZED),
    AUTH_005("AUTH-005", "Invalid token", HttpStatus.UNAUTHORIZED),
    AUTH_006("AUTH-006", "MFA required", HttpStatus.FORBIDDEN),

    // Registration errors
    REG_001("REG-001", "Email already registered", HttpStatus.CONFLICT),
    REG_002("REG-002", "Phone already registered", HttpStatus.CONFLICT),
    REG_003("REG-003", "Registration validation failed", HttpStatus.BAD_REQUEST),

    // Rate limiting
    RATE_001("RATE-001", "Rate limit exceeded", HttpStatus.TOO_MANY_REQUESTS),

    // Password errors
    PWD_001("PWD-001", "Password does not meet policy", HttpStatus.BAD_REQUEST),
    PWD_002("PWD-002", "Password recently used", HttpStatus.BAD_REQUEST),

    // General errors
    GEN_001("GEN-001", "Resource not found", HttpStatus.NOT_FOUND),
    GEN_002("GEN-002", "Validation failed", HttpStatus.BAD_REQUEST),
    GEN_999("GEN-999", "Internal server error", HttpStatus.INTERNAL_SERVER_ERROR);

    private final String code;
    private final String defaultMessage;
    private final HttpStatus httpStatus;

    ErrorCode(String code, String defaultMessage, HttpStatus httpStatus) {
        this.code = code;
        this.defaultMessage = defaultMessage;
        this.httpStatus = httpStatus;
    }

    public String getCode() { return code; }
    public String getDefaultMessage() { return defaultMessage; }
    public HttpStatus getHttpStatus() { return httpStatus; }
}
