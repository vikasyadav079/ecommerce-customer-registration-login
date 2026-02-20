package org.example.shared.exception;

public class ResourceNotFoundException extends BusinessException {

    public ResourceNotFoundException(String resourceType, Object id) {
        super(ErrorCode.GEN_001, resourceType + " not found with id: " + id);
    }
}
