package com.ecovision.backend.service;

import org.springframework.stereotype.Component;

@Component
public class InputSanitizer {
    public String plainText(String value, String fieldName, int maxLength) {
        if (value == null) {
            return null;
        }
        String normalized = value.trim().replaceAll("\\p{C}", "");
        if (normalized.length() > maxLength) {
            throw new IllegalArgumentException(fieldName + " çok uzun");
        }
        if (normalized.contains("<") || normalized.contains(">")) {
            throw new IllegalArgumentException(fieldName + " HTML içermemelidir");
        }
        return normalized;
    }
}
