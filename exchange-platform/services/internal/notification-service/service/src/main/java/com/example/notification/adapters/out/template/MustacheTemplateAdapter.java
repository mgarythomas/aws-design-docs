package com.example.notification.adapters.out.template;

import com.example.notification.application.ports.out.TemplatePort;
import com.github.mustachejava.DefaultMustacheFactory;
import com.github.mustachejava.Mustache;
import com.github.mustachejava.MustacheFactory;
import org.springframework.stereotype.Component;

import java.io.StringReader;
import java.io.StringWriter;
import java.util.Map;

@Component
public class MustacheTemplateAdapter implements TemplatePort {

    private final MustacheFactory mustacheFactory = new DefaultMustacheFactory();

    @Override
    public String render(String templateId, Map<String, Object> payload) {
        // Advanced implementations would load the actual raw template using the ID.
        // For simplicity, we assume the templateId acts as the body string or mock
        // lookup here
        String templateString = "Hello {{name}}, " + templateId;

        Mustache mustache = mustacheFactory.compile(new StringReader(templateString), templateId);
        StringWriter writer = new StringWriter();
        mustache.execute(writer, payload);
        return writer.toString();
    }
}
