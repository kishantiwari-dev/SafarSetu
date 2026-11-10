package in.safarsetu.backend.config;

import org.junit.jupiter.api.Test;
import org.springframework.core.env.StandardEnvironment;
import org.springframework.mock.env.MockEnvironment;

import static org.junit.jupiter.api.Assertions.assertDoesNotThrow;
import static org.junit.jupiter.api.Assertions.assertThrows;

class CorsConfigTest {
    @Test
    void acceptsExplicitExactHttpOriginsWithoutPathsOrWildcards() {
        assertDoesNotThrow(() -> new CorsConfig("", "https://demo.example.com,http://localhost:8081", new StandardEnvironment()));
        assertThrows(IllegalStateException.class, () -> new CorsConfig("", "*", new StandardEnvironment()));
        assertThrows(IllegalStateException.class, () -> new CorsConfig("", "https://demo.example.com/path", new StandardEnvironment()));
    }

    @Test
    void rejectsAmbiguousPatternAndExactOriginConfiguration() {
        assertThrows(IllegalStateException.class,
                () -> new CorsConfig("http://localhost:*", "https://demo.example.com", new StandardEnvironment()));
        var prodEnvironment = new MockEnvironment();
        prodEnvironment.setActiveProfiles("prod");
        assertThrows(IllegalStateException.class, () -> new CorsConfig("*", "", prodEnvironment));
    }
}
