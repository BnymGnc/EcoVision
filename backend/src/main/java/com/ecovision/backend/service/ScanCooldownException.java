package com.ecovision.backend.service;

public class ScanCooldownException extends RuntimeException {
    private final long retryAfterSeconds;

    public ScanCooldownException(long retryAfterSeconds) {
        super("Tarama sınırına ulaştınız. " + Math.max(1, retryAfterSeconds)
                + " saniye sonra tekrar deneyin.");
        this.retryAfterSeconds = Math.max(1, retryAfterSeconds);
    }

    public long getRetryAfterSeconds() {
        return retryAfterSeconds;
    }
}
