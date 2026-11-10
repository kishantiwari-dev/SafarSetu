package in.safarsetu.backend.config;

import java.net.URI;
import java.util.Arrays;
import java.util.List;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Configuration;
import org.springframework.core.env.Environment;
import org.springframework.core.env.Profiles;
import org.springframework.web.servlet.config.annotation.CorsRegistry;
import org.springframework.web.servlet.config.annotation.WebMvcConfigurer;

@Configuration
public class CorsConfig implements WebMvcConfigurer {
    private final List<String> allowedOriginPatterns;
    private final List<String> allowedOrigins;

    public CorsConfig(
            @Value("${safarsetu.cors.allowed-origin-patterns:}") String allowedOriginPatterns,
            @Value("${safarsetu.cors.allowed-origins:}") String allowedOrigins,
            Environment environment) {
        this.allowedOriginPatterns = split(allowedOriginPatterns);
        this.allowedOrigins = split(allowedOrigins);
        if (environment.acceptsProfiles(Profiles.of("prod")) && !this.allowedOriginPatterns.isEmpty()) {
            throw new IllegalStateException("Production CORS requires exact CORS_ALLOWED_ORIGINS values");
        }
        if (!this.allowedOriginPatterns.isEmpty() && !this.allowedOrigins.isEmpty()) {
            throw new IllegalStateException("Configure either CORS origin patterns or exact origins, not both");
        }
        this.allowedOrigins.forEach(CorsConfig::validateExactOrigin);
    }

    @Override
    public void addCorsMappings(CorsRegistry registry) {
        var cors = registry.addMapping("/api/**")
                .allowedMethods("GET", "POST", "OPTIONS")
                .allowedHeaders("Content-Type", "Idempotency-Key")
                .allowCredentials(false)
                .maxAge(3600);
        if (!allowedOriginPatterns.isEmpty()) {
            cors.allowedOriginPatterns(allowedOriginPatterns.toArray(String[]::new));
        } else if (!allowedOrigins.isEmpty()) {
            cors.allowedOrigins(allowedOrigins.toArray(String[]::new));
        }
    }

    private static List<String> split(String value) {
        if (value == null || value.isBlank()) return List.of();
        return Arrays.stream(value.split(","))
                .map(String::trim)
                .filter(origin -> !origin.isEmpty())
                .toList();
    }

    private static void validateExactOrigin(String origin) {
        try {
            URI uri = URI.create(origin);
            if (origin.contains("*") || !("http".equals(uri.getScheme()) || "https".equals(uri.getScheme()))
                    || uri.getHost() == null || uri.getUserInfo() != null
                    || (uri.getPath() != null && !uri.getPath().isEmpty())
                    || uri.getQuery() != null || uri.getFragment() != null) {
                throw new IllegalArgumentException();
            }
        } catch (IllegalArgumentException ex) {
            throw new IllegalStateException("CORS_ALLOWED_ORIGINS must contain exact HTTP(S) origins without paths or wildcards");
        }
    }
}
