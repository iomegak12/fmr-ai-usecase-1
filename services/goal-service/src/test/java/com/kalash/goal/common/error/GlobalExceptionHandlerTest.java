package com.kalash.goal.common.error;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

import com.kalash.goal.common.logging.CorrelationIdFilter;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import java.time.Clock;
import java.time.Instant;
import java.time.ZoneId;
import java.util.Set;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.EnumSource;
import org.slf4j.MDC;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.dao.OptimisticLockingFailureException;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;
import org.springframework.web.bind.annotation.*;

class GlobalExceptionHandlerTest {
  private MockMvc mvc;

  @BeforeEach
  void setup() {
    mvc =
        MockMvcBuilders.standaloneSetup(new BoundaryController())
            .setControllerAdvice(
                new GlobalExceptionHandler(
                    Clock.fixed(Instant.parse("2026-01-01T00:00:00Z"), ZoneId.of("Asia/Kolkata"))))
            .addFilters(new CorrelationIdFilter())
            .build();
  }

  @ParameterizedTest
  @EnumSource(ErrorCode.class)
  void everyCatalogueCodeHasCorrectProblemContract(ErrorCode code) throws Exception {
    var response =
        mvc.perform(
                get("/boundary/code/" + code.name())
                    .header("X-Correlation-ID", "unit-123")
                    .header("Origin", "https://example.invalid"))
            .andExpect(status().is(code.status()))
            .andExpect(content().contentTypeCompatibleWith(MediaType.APPLICATION_PROBLEM_JSON))
            .andExpect(header().string("X-Correlation-ID", "unit-123"))
            .andExpect(header().doesNotExist("Access-Control-Allow-Origin"))
            .andExpect(jsonPath("$.type").value("urn:kalash:error:" + code.code()))
            .andExpect(jsonPath("$.title").value(code.title()))
            .andExpect(jsonPath("$.detail").value(code.title()))
            .andExpect(jsonPath("$.errorCode").value(code.code()))
            .andExpect(jsonPath("$.correlationId").value("unit-123"))
            .andExpect(jsonPath("$.timestamp").value("2026-01-01T00:00:00Z"))
            .andExpect(jsonPath("$.instance").value("/boundary/code/" + code.name()));
    if (code == ErrorCode.COMMON_400) {
      response.andExpect(jsonPath("$.errors").isArray());
    } else {
      response.andExpect(jsonPath("$.errors").doesNotExist());
    }
    assertThat(MDC.get("correlationId")).isNull();
  }

  @Test
  void sanitizesUnexpectedAndDatabaseFailures() throws Exception {
    for (String failure : new String[] {"unexpected", "integrity"}) {
      mvc.perform(get("/boundary/failure/" + failure))
          .andExpect(status().isInternalServerError())
          .andExpect(jsonPath("$.errorCode").value("COMMON-500"))
          .andExpect(jsonPath("$.errors").doesNotExist())
          .andExpect(
              content()
                  .string(
                      org.hamcrest.Matchers.not(org.hamcrest.Matchers.containsString("secret"))));
    }
  }

  @Test
  void mapsConcurrencyAndMethodValidation() throws Exception {
    mvc.perform(get("/boundary/failure/optimistic"))
        .andExpect(status().isConflict())
        .andExpect(jsonPath("$.errorCode").value("COMMON-409"));
    mvc.perform(get("/boundary/failure/constraint"))
        .andExpect(status().isBadRequest())
        .andExpect(jsonPath("$.errors").isArray());
  }

  @Test
  void validatesBodiesAndMalformedRequestsWithoutLeakingRejectedValues() throws Exception {
    mvc.perform(
            post("/boundary").contentType(MediaType.APPLICATION_JSON).content("{\"name\":\"\"}"))
        .andExpect(status().isBadRequest())
        .andExpect(jsonPath("$.errors[0].field").value("name"));
    mvc.perform(post("/boundary").contentType(MediaType.APPLICATION_JSON).content("{secret"))
        .andExpect(status().isBadRequest())
        .andExpect(jsonPath("$.errorCode").value("COMMON-400"));
    mvc.perform(get("/boundary/id/not-a-uuid"))
        .andExpect(status().isBadRequest())
        .andExpect(jsonPath("$.errors").isArray());
    mvc.perform(get("/boundary"))
        .andExpect(status().isMethodNotAllowed())
        .andExpect(jsonPath("$.status").value(405))
        .andExpect(jsonPath("$.errorCode").doesNotExist());
  }

  @RestController
  static class BoundaryController {
    @GetMapping("/boundary/code/{code}")
    void code(@PathVariable ErrorCode code) {
      throw new ApiException(code);
    }

    @GetMapping("/boundary/failure/{failure}")
    void failure(@PathVariable String failure) {
      throw switch (failure) {
        case "optimistic" -> new OptimisticLockingFailureException("secret");
        case "integrity" -> new DataIntegrityViolationException("secret");
        case "constraint" ->
            new jakarta.validation.ConstraintViolationException("secret", Set.of());
        default -> new IllegalStateException("secret");
      };
    }

    @PostMapping("/boundary")
    void validate(@Valid @RequestBody Payload body) {}

    @GetMapping("/boundary/id/{id}")
    void identifier(@PathVariable UUID id) {}
  }

  record Payload(@NotBlank String name) {}
}
