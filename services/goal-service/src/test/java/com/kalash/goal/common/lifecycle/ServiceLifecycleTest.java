package com.kalash.goal.common.lifecycle;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.*;

import java.time.Duration;
import java.util.Properties;
import org.junit.jupiter.api.Test;
import org.springframework.boot.context.event.ApplicationReadyEvent;
import org.springframework.boot.info.BuildProperties;
import org.springframework.context.event.ContextClosedEvent;
import org.springframework.mock.env.MockEnvironment;

class ServiceLifecycleTest {
  private final MockEnvironment environment =
      new MockEnvironment()
          .withProperty("server.port", "8080")
          .withProperty("app.database-host", "localhost")
          .withProperty("app.database-port", "5432")
          .withProperty("app.database-name", "goal_db")
          .withProperty("app.timezone", "Asia/Kolkata")
          .withProperty("logging.level.root", "INFO")
          .withProperty("spring.datasource.password", "super-secret");

  private ServiceLifecycle lifecycle() {
    var properties = new Properties();
    properties.setProperty("version", "0.1.0-test");
    return new ServiceLifecycle(environment, new BuildProperties(properties));
  }

  @Test
  void rendersEveryRequiredGroupWithoutSecrets() {
    environment.setActiveProfiles("local");
    assertThat(lifecycle().summary(true, false, 12))
        .startsWith("\u001b[36m")
        .contains(
            "service=goal-service",
            "version=0.1.0-test",
            "profile=local",
            "java=",
            "port=8080",
            "api=http://localhost:8080/api/v1/goals",
            "/swagger-ui",
            "/v3/api-docs",
            "/health",
            "/ready",
            "/actuator/prometheus",
            "database=localhost:5432/goal_db",
            "timezone=Asia/Kolkata",
            "logLevel=INFO",
            "pid=",
            "startupMs=12")
        .doesNotContain("super-secret", "password");
  }

  @Test
  void colorRequiresTtyAndNoColorAbsentAndNonDocker() {
    assertThat(lifecycle().summary(false, false, 1)).doesNotContain("\u001b");
    assertThat(lifecycle().summary(true, true, 1)).doesNotContain("\u001b");
    environment.setActiveProfiles("docker");
    assertThat(lifecycle().summary(true, false, 1)).doesNotContain("\u001b");
  }

  @Test
  void lifecycleEventsWorkWithMinimalConfiguration() {
    var properties = new Properties();
    var minimal = new ServiceLifecycle(new MockEnvironment(), new BuildProperties(properties));
    assertThat(minimal.summary(false, false, 0)).contains("unknown");
    environment.setProperty("app.database-host", "host\r\n\u001b");
    assertThat(lifecycle().summary(false, false, 0)).doesNotContain("\r", "\n", "\u001b");
    var ready = mock(ApplicationReadyEvent.class);
    when(ready.getTimeTaken()).thenReturn(Duration.ofMillis(10));
    lifecycle().ready(ready);
    lifecycle().closed(mock(ContextClosedEvent.class));
  }
}
