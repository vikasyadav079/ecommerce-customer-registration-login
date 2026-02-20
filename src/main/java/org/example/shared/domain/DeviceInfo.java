package org.example.shared.domain;

public record DeviceInfo(
        String fingerprint,
        String name,
        String type,
        String os,
        String browser,
        String ip,
        String userAgent
) {}
