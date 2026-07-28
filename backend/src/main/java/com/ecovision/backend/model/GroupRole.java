package com.ecovision.backend.model;

public enum GroupRole {
    FOUNDER,
    ADMIN,
    /**
     * Kept only so existing databases can be migrated without enum read errors.
     */
    GROUP_ADMIN,
    MEMBER
}
