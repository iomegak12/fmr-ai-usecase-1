package com.kalash.goal;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

import com.kalash.goal.goal.repository.GoalRepository;
import java.util.concurrent.atomic.AtomicBoolean;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.config.YamlPropertiesFactoryBean;
import org.springframework.boot.health.contributor.Health;
import org.springframework.boot.health.contributor.HealthIndicator;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.context.TestConfiguration;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.context.annotation.Bean;
import org.springframework.core.io.ClassPathResource;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.transaction.PlatformTransactionManager;

/**
 * The {@code test} profile has no DataSource, so it drops {@code db} from readiness. This context
 * restores the production group and stands in for the database health check.
 */
@SpringBootTest(
    webEnvironment = SpringBootTest.WebEnvironment.MOCK,
    properties = "management.endpoint.health.group.readiness.include=" + ReadinessContextTest.GROUP)
@AutoConfigureMockMvc
@ActiveProfiles("test")
class ReadinessContextTest {
  static final String GROUP = "readinessState,db";
  static final AtomicBoolean DATABASE_UP = new AtomicBoolean(true);

  @MockitoBean GoalRepository goalRepository;
  @MockitoBean PlatformTransactionManager transactionManager;
  @Autowired MockMvc mvc;

  @TestConfiguration
  static class DatabaseHealth {
    @Bean("db")
    HealthIndicator db() {
      return () -> DATABASE_UP.get() ? Health.up().build() : Health.down().build();
    }
  }

  @AfterEach
  void restore() {
    DATABASE_UP.set(true);
  }

  @Test
  void productionReadinessGroupIncludesTheDatabase() {
    var yaml = new YamlPropertiesFactoryBean();
    yaml.setResources(new ClassPathResource("application.yml"));
    assertThat(yaml.getObject())
        .containsEntry("management.endpoint.health.group.readiness.include", GROUP);
  }

  @Test
  void readyFollowsTheDatabaseWhileHealthStaysUp() throws Exception {
    mvc.perform(get("/ready"))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.status").value("UP"));

    DATABASE_UP.set(false);
    mvc.perform(get("/ready"))
        .andExpect(status().isServiceUnavailable())
        .andExpect(jsonPath("$.status").value("DOWN"))
        .andExpect(jsonPath("$.components").doesNotExist());
    mvc.perform(get("/health"))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.status").value("UP"));

    DATABASE_UP.set(true);
    mvc.perform(get("/ready")).andExpect(status().isOk());
  }
}
