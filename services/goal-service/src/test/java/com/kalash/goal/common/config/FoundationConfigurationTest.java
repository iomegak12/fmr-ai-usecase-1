package com.kalash.goal.common.config;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import java.time.DateTimeException;
import java.time.ZoneId;
import org.junit.jupiter.api.Test;

class FoundationConfigurationTest {
  private final FoundationConfiguration configuration = new FoundationConfiguration();

  @Test
  void clockUsesConfiguredTimezoneInsteadOfMachineDefault() {
    assertThat(configuration.applicationClock("Asia/Kolkata").getZone())
        .isEqualTo(ZoneId.of("Asia/Kolkata"));
    assertThat(configuration.applicationClock("UTC").getZone()).isEqualTo(ZoneId.of("UTC"));
    assertThatThrownBy(() -> configuration.applicationClock("invalid"))
        .isInstanceOf(DateTimeException.class);
  }

  @Test
  void documentationUsesPublicOriginNotGatewayDocumentationPrefix() {
    var openApi = configuration.goalOpenApi();
    assertThat(openApi.getServers())
        .singleElement()
        .satisfies(server -> assertThat(server.getUrl()).isEqualTo("/"));
    assertThat(openApi.getTags())
        .singleElement()
        .satisfies(tag -> assertThat(tag.getName()).isEqualTo("Internal"));
    assertThat(openApi.getInfo().getTitle()).isEqualTo("Kalash Goal Service");
  }
}
