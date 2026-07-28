package com.ecovision.backend.dto;

import com.ecovision.backend.model.MapPinBin;

public record MapPinBinResponse(
        String contentType,
        int level,
        boolean state
) {
    public static MapPinBinResponse from(MapPinBin bin) {
        return new MapPinBinResponse(
                bin.getContentType(),
                bin.getLevel(),
                bin.isState()
        );
    }
}
