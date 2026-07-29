package com.ecovision.backend.dto;

import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;

public record PollVoteRequest(@Min(0) @Max(3) int optionIndex) {
}
