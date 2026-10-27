package com.kalash.goal.common.config;

import io.swagger.v3.oas.models.OpenAPI;
import io.swagger.v3.oas.models.info.Info;
import io.swagger.v3.oas.models.servers.Server;
import io.swagger.v3.oas.models.tags.Tag;
import java.time.Clock;
import java.time.ZoneId;
import java.util.List;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration(proxyBeanMethods = false)
public class FoundationConfiguration {
  @Bean
  Clock applicationClock(@Value("${app.timezone}") String timezone) {
    return Clock.system(ZoneId.of(timezone));
  }

  @Bean
  OpenAPI goalOpenApi() {
    return new OpenAPI()
        .info(new Info().title("Kalash Goal Service").version("0.1.0"))
        .servers(
            List.of(new Server().url("/").description("Public API origin (direct or gateway)")))
        .tags(List.of(new Tag().name("Internal").description("Service-to-service operations")));
  }
}
