package com.kalash.goal.common.error;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

import jakarta.validation.Valid;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotNull;
import java.time.Clock;
import java.time.Instant;
import java.time.ZoneId;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.TestConfiguration;
import org.springframework.boot.webmvc.test.autoconfigure.WebMvcTest;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Import;
import org.springframework.http.MediaType;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.web.bind.annotation.*;

@WebMvcTest(WebBoundarySliceTest.ValidationController.class)
@Import({WebBoundarySliceTest.ValidationController.class, WebBoundarySliceTest.FixedClock.class})
@ActiveProfiles("test")
class WebBoundarySliceTest {
  @Autowired MockMvc mvc;

  @Test
  void bootJsonConfigurationRejectsFractionalMoneyAndOverflow() throws Exception {
    for (String number : new String[] {"1.5", "9223372036854775808"}) {
      mvc.perform(
              post("/slice")
                  .contentType(MediaType.APPLICATION_JSON)
                  .content("{\"amount\":" + number + "}"))
          .andExpect(status().isBadRequest())
          .andExpect(jsonPath("$.errorCode").value("COMMON-400"))
          .andExpect(jsonPath("$.timestamp").value("2026-01-01T00:00:00Z"))
          .andExpect(jsonPath("$.errors").isArray());
    }
    mvc.perform(post("/slice").contentType(MediaType.APPLICATION_JSON).content("{\"amount\":1}"))
        .andExpect(status().isOk());
  }

  @Test
  void validatesBodyAndMethodArgumentsWithProductionAdvice() throws Exception {
    mvc.perform(post("/slice").contentType(MediaType.APPLICATION_JSON).content("{}"))
        .andExpect(status().isBadRequest())
        .andExpect(jsonPath("$.errors[0].field").value("amount"));
    mvc.perform(get("/slice").param("size", "0"))
        .andExpect(status().isBadRequest())
        .andExpect(jsonPath("$.errorCode").value("COMMON-400"));
  }

  @RestController
  static class ValidationController {
    @PostMapping("/slice")
    void body(@Valid @RequestBody Amount body) {}

    @GetMapping("/slice")
    void parameter(@RequestParam @Min(1) int size) {}
  }

  record Amount(@NotNull Long amount) {}

  @TestConfiguration(proxyBeanMethods = false)
  static class FixedClock {
    @Bean
    Clock clock() {
      return Clock.fixed(Instant.parse("2026-01-01T00:00:00Z"), ZoneId.of("Asia/Kolkata"));
    }
  }
}
