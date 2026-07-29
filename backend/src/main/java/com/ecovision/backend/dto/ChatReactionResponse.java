package com.ecovision.backend.dto;

import java.util.List;

public record ChatReactionResponse(String emoji, List<Long> userIds) {
}
