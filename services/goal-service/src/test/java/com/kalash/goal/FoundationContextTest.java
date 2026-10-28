package com.kalash.goal;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

import com.kalash.goal.goal.repository.GoalRepository;
import java.time.Clock;
import java.time.ZoneId;
import javax.sql.DataSource;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.context.ApplicationContext;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.transaction.PlatformTransactionManager;

@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.MOCK)
@AutoConfigureMockMvc
@ActiveProfiles("test")
class FoundationContextTest {
  @MockitoBean GoalRepository goalRepository;
  @MockitoBean PlatformTransactionManager transactionManager;
  @Autowired MockMvc mvc;
  @Autowired ApplicationContext context;
  @Autowired Clock clock;

  @Test
  void testProfileHasNoDatabaseAndCorrectClock() {
    assertThat(context.getBeansOfType(DataSource.class)).isEmpty();
    assertThat(clock.getZone()).isEqualTo(ZoneId.of("Asia/Kolkata"));
  }

  @Test
  void healthDocumentationMetricsAndGatewayPrefixWorkWithoutCors() throws Exception {
    for (String path : new String[] {"/health", "/ready", "/v3/api-docs", "/actuator/prometheus"}) {
      mvc.perform(get(path).header("Origin", "https://example.invalid"))
          .andExpect(status().isOk())
          .andExpect(header().exists("X-Correlation-ID"))
          .andExpect(header().doesNotExist("Access-Control-Allow-Origin"));
    }
    mvc.perform(get("/swagger-ui")).andExpect(status().is3xxRedirection());
    mvc.perform(get("/v3/api-docs"))
        .andExpect(
            jsonPath("$.paths['/api/v1/goals'].post.responses['201'].headers.Location").exists())
        .andExpect(
            jsonPath(
                    "$.paths['/api/v1/goals'].get.responses['200'].content['*/*'].example.totalElements")
                .value(1))
        .andExpect(
            jsonPath(
                    "$.paths['/api/v1/goals/{goalId}'].get.responses['404'].content['application/problem+json'].examples['GOAL-001'].value.errorCode")
                .value("GOAL-001"))
        .andExpect(
            jsonPath("$.paths['/internal/v1/goals/{goalId}/balance-adjustments'].post.tags[0]")
                .value("Internal"));
    mvc.perform(get("/v3/api-docs").header("X-Forwarded-Prefix", "/docs/goals"))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.servers[0].url").value("/"));
    mvc.perform(get("/v3/api-docs/swagger-config").header("X-Forwarded-Prefix", "/docs/goals"))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.url").value("/docs/goals/v3/api-docs"));
  }
}
