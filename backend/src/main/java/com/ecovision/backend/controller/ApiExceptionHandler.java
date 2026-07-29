package com.ecovision.backend.controller;

import com.ecovision.backend.dto.ApiError;
import jakarta.servlet.http.HttpServletRequest;
import java.time.Instant;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.http.converter.HttpMessageNotReadableException;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.security.authentication.LockedException;
import org.springframework.security.core.AuthenticationException;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.server.ResponseStatusException;

@RestControllerAdvice
public class ApiExceptionHandler {
    private static final Logger LOGGER = LoggerFactory.getLogger(ApiExceptionHandler.class);

    @ExceptionHandler(IllegalArgumentException.class)
    ResponseEntity<ApiError> badRequest(
            IllegalArgumentException exception,
            HttpServletRequest request
    ) {
        return error(HttpStatus.BAD_REQUEST, safeMessage(exception), request);
    }

    @ExceptionHandler(MethodArgumentNotValidException.class)
    ResponseEntity<ApiError> validation(
            MethodArgumentNotValidException exception,
            HttpServletRequest request
    ) {
        String message = exception.getBindingResult()
                .getFieldErrors()
                .stream()
                .findFirst()
                .map(fieldError -> fieldError.getField() + " " + fieldError.getDefaultMessage())
                .orElse("Girilen bilgiler geçersiz");
        return error(HttpStatus.BAD_REQUEST, message, request);
    }

    @ExceptionHandler(HttpMessageNotReadableException.class)
    ResponseEntity<ApiError> unreadableBody(HttpServletRequest request) {
        return error(HttpStatus.BAD_REQUEST, "İstek içeriği okunamadı", request);
    }

    @ExceptionHandler(LockedException.class)
    ResponseEntity<ApiError> locked(HttpServletRequest request) {
        return error(
                HttpStatus.LOCKED,
                "Çok fazla başarısız deneme. Hesap 15 dakika kilitlendi",
                request
        );
    }

    @ExceptionHandler(AuthenticationException.class)
    ResponseEntity<ApiError> authentication(HttpServletRequest request) {
        return error(HttpStatus.UNAUTHORIZED, "E-posta veya parola hatalı", request);
    }

    @ExceptionHandler(AccessDeniedException.class)
    ResponseEntity<ApiError> accessDenied(HttpServletRequest request) {
        return error(HttpStatus.FORBIDDEN, "Bu işlem için yetkiniz yok", request);
    }

    @ExceptionHandler(ResponseStatusException.class)
    ResponseEntity<ApiError> responseStatus(
            ResponseStatusException exception,
            HttpServletRequest request
    ) {
        HttpStatus status = HttpStatus.valueOf(exception.getStatusCode().value());
        String message = exception.getReason() == null
                ? "İstek tamamlanamadı"
                : exception.getReason();
        return error(status, message, request);
    }

    @ExceptionHandler(Exception.class)
    ResponseEntity<ApiError> generic(Exception exception, HttpServletRequest request) {
        LOGGER.error("Unhandled API error on {}", request.getRequestURI(), exception);
        return error(
                HttpStatus.INTERNAL_SERVER_ERROR,
                "Beklenmeyen bir sunucu hatası oluştu",
                request
        );
    }

    private ResponseEntity<ApiError> error(
            HttpStatus status,
            String message,
            HttpServletRequest request
    ) {
        return ResponseEntity.status(status).body(new ApiError(
                Instant.now(),
                status.value(),
                status.getReasonPhrase(),
                message,
                request.getRequestURI()
        ));
    }

    private String safeMessage(IllegalArgumentException exception) {
        String message = exception.getMessage();
        return message == null || message.isBlank() ? "İstek geçersiz" : message;
    }
}
