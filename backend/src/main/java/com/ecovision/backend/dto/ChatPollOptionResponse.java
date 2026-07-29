package com.ecovision.backend.dto;

import java.util.List;

public record ChatPollOptionResponse(
        int index,
        String text,
        List<Long> voterIds
) {
}
