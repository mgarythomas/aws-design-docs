package com.det.exchange.validation.controller;

import com.det.exchange.validation.service.OpaValidationService;
import com.fasterxml.jackson.databind.JsonNode;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/v1/validate")
@RequiredArgsConstructor
public class ValidationController {

    private final OpaValidationService opaValidationService;

    @PostMapping("/corporate-action")
    public ResponseEntity<JsonNode> validateCorporateAction(@RequestBody JsonNode document) {
        return ResponseEntity.ok(opaValidationService.validateDocument(document));
    }

    @PostMapping("/field")
    public ResponseEntity<JsonNode> validateField(@RequestBody JsonNode fieldRequest) {
        return ResponseEntity.ok(opaValidationService.validateField(fieldRequest));
    }
}
