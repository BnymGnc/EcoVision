package com.ecovision.backend.model;

import jakarta.persistence.Column;
import jakarta.persistence.Embeddable;
import java.util.Objects;

@Embeddable
public class MapPinBin {
    @Column(name = "content_type", nullable = false, length = 30)
    private String contentType;

    @Column(name = "fill_level", nullable = false)
    private int level;

    @Column(name = "accepting", nullable = false)
    private boolean state;

    protected MapPinBin() {
    }

    public MapPinBin(String contentType, int level, boolean state) {
        this.contentType = contentType;
        this.level = level;
        this.state = state;
    }

    public String getContentType() {
        return contentType;
    }

    public int getLevel() {
        return level;
    }

    public boolean isState() {
        return state;
    }

    @Override
    public boolean equals(Object other) {
        if (this == other) {
            return true;
        }
        if (!(other instanceof MapPinBin that)) {
            return false;
        }
        return level == that.level
                && state == that.state
                && Objects.equals(contentType, that.contentType);
    }

    @Override
    public int hashCode() {
        return Objects.hash(contentType, level, state);
    }
}
