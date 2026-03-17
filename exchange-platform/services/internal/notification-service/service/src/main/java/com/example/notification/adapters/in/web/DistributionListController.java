package com.example.notification.adapters.in.web;

import com.example.notification.application.ports.in.ListManagementUseCase;
import com.example.notification.domain.DistributionList;
import com.example.notification.domain.Subscriber;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.net.URI;
import java.time.Instant;
import java.util.List;
import java.util.Map;
import java.util.UUID;

/**
 * Primary adapter exposing distribution list management over REST.
 * Maps HTTP requests to {@link ListManagementUseCase} inbound port operations.
 */
@RestController
@RequestMapping("/v1/distribution-lists")
public class DistributionListController {

    private final ListManagementUseCase listManagementUseCase;

    public DistributionListController(ListManagementUseCase listManagementUseCase) {
        this.listManagementUseCase = listManagementUseCase;
    }

    @PostMapping
    public ResponseEntity<DistributionListResponse> createList(@RequestBody CreateListRequest request) {
        DistributionList list = listManagementUseCase.createList(request.name(), request.description());
        return ResponseEntity
                .created(URI.create("/v1/distribution-lists/" + list.getId()))
                .body(DistributionListResponse.from(list));
    }

    @GetMapping("/{listId}")
    public ResponseEntity<DistributionListResponse> getList(@PathVariable UUID listId) {
        DistributionList list = listManagementUseCase.getList(listId);
        return ResponseEntity.ok(DistributionListResponse.from(list));
    }

    @PostMapping("/{listId}/subscribers")
    public ResponseEntity<Void> addSubscribers(@PathVariable UUID listId,
            @RequestBody List<SubscriberRequest> requests) {
        List<Subscriber> subscribers = requests.stream().map(SubscriberRequest::toDomain).toList();
        listManagementUseCase.addSubscribers(listId, subscribers);
        return ResponseEntity.ok().build();
    }

    @DeleteMapping("/{listId}/subscribers/{subscriberId}")
    public ResponseEntity<Void> removeSubscriber(@PathVariable UUID listId,
            @PathVariable String subscriberId) {
        listManagementUseCase.removeSubscriber(listId, subscriberId);
        return ResponseEntity.noContent().build();
    }

    // ── Request / Response records ───────────────────────────────────────────

    public record CreateListRequest(String name, String description) {}

    public record SubscriberRequest(
            String subscriberId,
            String email,
            String firstName,
            String lastName,
            Map<String, Object> attributes) {

        public Subscriber toDomain() {
            return Subscriber.builder()
                    .subscriberId(subscriberId)
                    .email(email)
                    .firstName(firstName)
                    .lastName(lastName)
                    .attributes(attributes)
                    .build();
        }
    }

    public record DistributionListResponse(
            UUID listId,
            String name,
            String description,
            String externalKey,
            int subscriberCount,
            Instant createdAt) {

        public static DistributionListResponse from(DistributionList dl) {
            return new DistributionListResponse(
                    dl.getId(), dl.getName(), dl.getDescription(),
                    dl.getExternalKey(), dl.getSubscriberCount(), dl.getCreatedAt());
        }
    }
}
