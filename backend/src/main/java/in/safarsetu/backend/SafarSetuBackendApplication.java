package in.safarsetu.backend;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

@SpringBootApplication
public class SafarSetuBackendApplication {
    public static void main(String[] args) {
        validateDatabaseConfiguration();
        SpringApplication.run(SafarSetuBackendApplication.class, args);
    }

    private static void validateDatabaseConfiguration() {
        String url = configurationValue("DB_URL");
        String username = configurationValue("DB_USERNAME");
        String password = configurationValue("DB_PASSWORD");
        if (url == null || url.isBlank() || username == null || username.isBlank()
                || password == null || password.isBlank()) {
            throw new IllegalStateException(
                    "Missing required PostgreSQL configuration. Set DB_URL, DB_USERNAME, and DB_PASSWORD before startup.");
        }
        if (!url.startsWith("jdbc:postgresql:")) {
            throw new IllegalStateException("DB_URL must be a PostgreSQL JDBC URL beginning with jdbc:postgresql:");
        }
    }

    private static String configurationValue(String name) {
        String systemProperty = System.getProperty(name);
        return systemProperty != null ? systemProperty : System.getenv(name);
    }
}
