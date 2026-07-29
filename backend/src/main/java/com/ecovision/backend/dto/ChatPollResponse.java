package com.ecovision.backend.dto;

import java.util.List;

public record ChatPollResponse(
        Long id,
        String question,
        List<ChatPollOptionResponse> options,
        int totalVotes
) {
}
