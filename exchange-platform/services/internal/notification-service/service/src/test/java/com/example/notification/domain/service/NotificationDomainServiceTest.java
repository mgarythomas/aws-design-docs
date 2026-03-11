package com.example.notification.domain.service;

import com.example.notification.application.ports.out.AuditPort;
import com.example.notification.application.ports.out.NotificationChannelPort;
import com.example.notification.application.ports.out.TemplatePort;
import com.example.notification.domain.Notification;
import dev.openfeature.sdk.OpenFeatureAPI;
import dev.openfeature.sdk.providers.memory.Flag;
import dev.openfeature.sdk.providers.memory.InMemoryProvider;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.util.HashMap;
import java.util.List;
import java.util.Map;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class NotificationDomainServiceTest {

    @Mock
    private NotificationChannelPort emailChannel;

    @Mock
    private TemplatePort templatePort;

    @Mock
    private AuditPort auditPort;

    private NotificationDomainService service;

    @BeforeEach
    void setUp() {
        Map<String, Flag<?>> flags = new HashMap<>();
        flags.put("channel-email-enabled", Flag.builder().variant("on", true).defaultVariant("on").build());
        flags.put("channel-sms-enabled", Flag.builder().variant("off", false).defaultVariant("off").build());
        OpenFeatureAPI.getInstance().setProviderAndWait(new InMemoryProvider(flags));

        lenient().when(emailChannel.supports("EMAIL")).thenReturn(true);
        lenient().when(emailChannel.supports("SMS")).thenReturn(false);

        service = new NotificationDomainService(List.of(emailChannel), templatePort, auditPort);
    }

    @Test
    void testSend_Success() {
        Notification notification = Notification.create("EMAIL", "test@example.com", "SystemA", "template-1", Map.of());
        when(templatePort.render(eq("template-1"), any())).thenReturn("Rendered Content");
        when(emailChannel.dispatch(notification, "Rendered Content")).thenReturn("DELIVERED");

        String result = service.send(notification);

        assertEquals("DELIVERED", result);
        verify(emailChannel).dispatch(notification, "Rendered Content");
        verify(auditPort).recordAudit(notification, "DELIVERED");
    }

    @Test
    void testSend_FeatureFlagRejected() {
        Notification notification = Notification.create("SMS", "+1234567890", "SystemA", "template-1", Map.of());

        String result = service.send(notification);

        assertEquals("REJECTED", result);
        verify(emailChannel, never()).dispatch(any(), anyString());
        verify(auditPort).recordAudit(notification, "REJECTED_FEATURE_FLAG");
    }

    @Test
    void testSend_UnsupportedChannel() {
        // Change feature flag temporarily for this test
        Map<String, Flag<?>> flags = new HashMap<>();
        flags.put("channel-push-enabled", Flag.builder().variant("on", true).defaultVariant("on").build());
        OpenFeatureAPI.getInstance().setProviderAndWait(new InMemoryProvider(flags));

        Notification notification = Notification.create("PUSH", "device-token", "SystemA", "template-1", Map.of());
        when(templatePort.render(anyString(), any())).thenReturn("Content");

        IllegalArgumentException thrown = assertThrows(IllegalArgumentException.class,
                () -> service.send(notification));
        assertEquals("Unsupported channel: PUSH", thrown.getMessage());

        verify(auditPort).recordAudit(notification, "FAILED");
    }

    @Test
    void testSend_DispatchException() {
        Notification notification = Notification.create("EMAIL", "test@example.com", "SystemA", "template-1", Map.of());
        when(templatePort.render(any(), any())).thenReturn("Content");
        when(emailChannel.dispatch(any(), any())).thenThrow(new RuntimeException("Network Error"));

        assertThrows(RuntimeException.class, () -> service.send(notification));

        verify(auditPort).recordAudit(notification, "FAILED");
    }

    @Test
    void testSendBatch() {
        Notification n1 = Notification.create("EMAIL", "test1@example.com", "Sys", "t1", Map.of());
        Notification n2 = Notification.create("SMS", "+1", "Sys", "t1", Map.of());

        when(templatePort.render(anyString(), any())).thenReturn("Content");
        when(emailChannel.dispatch(eq(n1), anyString())).thenReturn("DELIVERED");

        List<String> results = service.sendBatch(List.of(n1, n2));

        assertEquals(2, results.size());
        assertEquals("DELIVERED", results.get(0));
        assertEquals("REJECTED", results.get(1)); // Because SMS is disabled by default flag

        verify(auditPort).recordAudit(n1, "DELIVERED");
        verify(auditPort).recordAudit(n2, "REJECTED_FEATURE_FLAG");
    }
}
