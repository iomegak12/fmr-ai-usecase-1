package com.kalash.goal.goal.api;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

import com.kalash.goal.balance.api.*;
import com.kalash.goal.balance.service.BalanceAdjustmentService;
import com.kalash.goal.common.error.*;
import com.kalash.goal.goal.domain.*;
import com.kalash.goal.goal.service.GoalService;
import com.kalash.goal.insights.InsightsCalculator;
import java.time.*;
import java.util.List;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.*;
import org.mockito.ArgumentCaptor;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.TestConfiguration;
import org.springframework.boot.webmvc.test.autoconfigure.WebMvcTest;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Import;
import org.springframework.http.MediaType;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;

@WebMvcTest({GoalController.class, BalanceAdjustmentController.class})
@Import(GoalApiTest.FixedTime.class)
@ActiveProfiles("test")
class GoalApiTest {
  @Autowired tools.jackson.databind.json.JsonMapper mapper;

  @Test
  void deserializationPreservesOmittedPatchFields() {
    var patch = mapper.readValue("{\"name\":\"New\"}", UpdateGoalRequest.class);
    assertThat(patch.name()).isEqualTo("New");
    assertThat(patch.targetAmount()).isNull();
  }

  @Autowired MockMvc mvc;
  @Autowired Clock clock;
  @MockitoBean GoalService goals;
  @MockitoBean BalanceAdjustmentService balances;
  private final UUID id = UUID.fromString("10000000-0000-0000-0000-000000000001");
  private Goal goal;
  private GoalResponse response;

  @BeforeEach
  void setup() {
    goal =
        new Goal("Trip", 100, LocalDate.of(2027, 3, 1), OffsetDateTime.parse("2026-10-01T00:00Z"));
    response = GoalResponse.from(goal, new InsightsCalculator(clock).calculate(goal));
  }

  @Test
  void allEightEndpointsHaveTheSpecifiedResponseShapes() throws Exception {
    when(goals.create(any())).thenReturn(response);
    when(goals.get(id)).thenReturn(response);
    when(goals.update(eq(id), any())).thenReturn(response);
    when(goals.cancel(id)).thenReturn(response);
    when(goals.list(0, 20)).thenReturn(new PageResponse<>(List.of(response), 0, 20, 1, 1));
    when(goals.require(id)).thenReturn(goal);
    when(balances.adjust(eq(id), any())).thenReturn(GoalSnapshot.from(goal));

    mvc.perform(
            post("/api/v1/goals")
                .contentType(MediaType.APPLICATION_JSON)
                .header("X-Correlation-ID", "p2-contract")
                .header("Origin", "https://example.invalid")
                .content("{\"name\":\"Trip\",\"targetAmount\":100,\"targetDate\":\"2027-03-01\"}"))
        .andExpect(status().isCreated())
        .andExpect(header().string("Location", "/api/v1/goals/" + goal.goalId()))
        .andExpect(header().string("X-Correlation-ID", "p2-contract"))
        .andExpect(header().doesNotExist("Access-Control-Allow-Origin"))
        .andExpect(jsonPath("$.goalId").value(goal.goalId().toString()))
        .andExpect(jsonPath("$.targetAmount").value(100))
        .andExpect(jsonPath("$.status").value("ACTIVE"))
        .andExpect(jsonPath("$.insights.remainingAmount").value(100))
        .andExpect(jsonPath("$.version").doesNotExist());
    mvc.perform(get("/api/v1/goals"))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.content[0].name").value("Trip"))
        .andExpect(jsonPath("$.page").value(0))
        .andExpect(jsonPath("$.size").value(20))
        .andExpect(jsonPath("$.totalElements").value(1))
        .andExpect(jsonPath("$.totalPages").value(1));
    mvc.perform(get("/api/v1/goals/" + id)).andExpect(status().isOk());
    mvc.perform(
            patch("/api/v1/goals/" + id)
                .contentType(MediaType.APPLICATION_JSON)
                .content("{\"name\":\"New\"}"))
        .andExpect(status().isOk());
    ArgumentCaptor<UpdateGoalRequest> captured = ArgumentCaptor.forClass(UpdateGoalRequest.class);
    verify(goals).update(eq(id), captured.capture());
    assertThat(captured.getValue().targetAmount()).isNull();
    mvc.perform(post("/api/v1/goals/" + id + "/cancel")).andExpect(status().isOk());
    mvc.perform(get("/internal/v1/goals/" + id))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.balance").value(0))
        .andExpect(jsonPath("$.insights").doesNotExist());
    mvc.perform(
            post("/internal/v1/goals/" + id + "/balance-adjustments")
                .contentType(MediaType.APPLICATION_JSON)
                .content("{\"operation\":\"DEPOSIT\",\"delta\":1}"))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.targetAmount").value(100));
    mvc.perform(delete("/internal/v1/goals/" + id))
        .andExpect(status().isNoContent())
        .andExpect(content().string(""));
    verify(goals).deleteCancelled(id);
  }

  @ParameterizedTest
  @ValueSource(
      strings = {
        "{}",
        "{\"name\":\"\",\"targetAmount\":1,\"targetDate\":\"2027-01-01\"}",
        "{\"name\":\" \",\"targetAmount\":1,\"targetDate\":\"2027-01-01\"}",
        "{\"name\":\"G\",\"targetAmount\":0,\"targetDate\":\"2027-01-01\"}",
        "{\"name\":\"G\",\"targetAmount\":-1,\"targetDate\":\"2027-01-01\"}",
        "{\"name\":\"G\",\"targetAmount\":1.0,\"targetDate\":\"2027-01-01\"}",
        "{\"name\":\"G\",\"targetAmount\":\"1\",\"targetDate\":\"2027-01-01\"}",
        "{\"name\":\"G\",\"targetAmount\":9223372036854775808,\"targetDate\":\"2027-01-01\"}",
        "{\"name\":\"G\",\"targetAmount\":true,\"targetDate\":\"2027-01-01\"}",
        "{\"name\":\"G\",\"targetAmount\":1,\"targetDate\":\"2027-02-30\"}"
      })
  void invalidCreateFieldsNeverReachBusinessLayer(String body) throws Exception {
    mvc.perform(post("/api/v1/goals").contentType(MediaType.APPLICATION_JSON).content(body))
        .andExpect(status().isBadRequest())
        .andExpect(jsonPath("$.errorCode").value("COMMON-400"))
        .andExpect(jsonPath("$.errors").isArray());
    verifyNoInteractions(goals);
  }

  @ParameterizedTest
  @ValueSource(
      strings = {
        "{}", "{\"name\":null}", "{\"targetAmount\":null}", "{\"targetDate\":null}",
        "{\"unknown\":1}", "{\"name\":\"\"}", "{\"name\":\"   \"}", "{\"targetAmount\":0}",
        "{\"targetAmount\":1.1}", "{\"targetAmount\":\"100\"}", "{\"targetDate\":\"bad\"}"
      })
  void invalidPatchIs400(String body) throws Exception {
    mvc.perform(patch("/api/v1/goals/" + id).contentType(MediaType.APPLICATION_JSON).content(body))
        .andExpect(status().isBadRequest())
        .andExpect(jsonPath("$.errorCode").value("COMMON-400"));
    verifyNoInteractions(goals);
  }

  @ParameterizedTest
  @ValueSource(
      strings = {"{\"name\":\"New\"}", "{\"targetAmount\":200}", "{\"targetDate\":\"2027-03-01\"}"})
  void omittedPatchFieldsAreAllowed(String body) throws Exception {
    when(goals.update(eq(id), any())).thenReturn(response);
    mvc.perform(patch("/api/v1/goals/" + id).contentType(MediaType.APPLICATION_JSON).content(body))
        .andExpect(status().isOk());
  }

  @Test
  void nameLengthAndPageBoundsAndBadUuidAreValidated() throws Exception {
    mvc.perform(
            post("/api/v1/goals")
                .contentType(MediaType.APPLICATION_JSON)
                .content(
                    "{\"name\":\""
                        + "x".repeat(101)
                        + "\",\"targetAmount\":1,\"targetDate\":\"2027-01-01\"}"))
        .andExpect(status().isBadRequest());
    for (String query :
        List.of("?page=-1", "?size=0", "?size=101", "?page=2147483648", "?page=x")) {
      mvc.perform(get("/api/v1/goals" + query))
          .andExpect(status().isBadRequest())
          .andExpect(jsonPath("$.errorCode").value("COMMON-400"));
    }
    mvc.perform(get("/api/v1/goals/not-a-uuid")).andExpect(status().isBadRequest());
    when(goals.list(0, 100)).thenReturn(new PageResponse<>(List.of(), 0, 100, 0, 0));
    mvc.perform(get("/api/v1/goals?size=100")).andExpect(status().isOk());
  }

  @ParameterizedTest
  @ValueSource(
      strings = {
        "{}",
        "{\"operation\":\"UNKNOWN\",\"delta\":1}",
        "{\"operation\":\"DEPOSIT\",\"delta\":null}",
        "{\"operation\":\"DEPOSIT\",\"delta\":1.0}",
        "{\"operation\":\"DEPOSIT\",\"delta\":\"1\"}",
        "{\"operation\":\"DEPOSIT\",\"delta\":9223372036854775808}"
      })
  void internalAdjustmentValidation(String body) throws Exception {
    mvc.perform(
            post("/internal/v1/goals/" + id + "/balance-adjustments")
                .contentType(MediaType.APPLICATION_JSON)
                .content(body))
        .andExpect(status().isBadRequest());
    verifyNoInteractions(balances);
  }

  @ParameterizedTest
  @EnumSource(
      value = ErrorCode.class,
      names = {
        "GOAL_001",
        "GOAL_002",
        "GOAL_003",
        "GOAL_004",
        "GOAL_005",
        "GOAL_006",
        "GOAL_007",
        "GOAL_008",
        "GOAL_009",
        "GOAL_010",
        "GOAL_011",
        "GOAL_012",
        "COMMON_409",
        "COMMON_500"
      })
  void catalogueRejectionsUseProblemDetails(ErrorCode code) throws Exception {
    when(goals.get(id)).thenThrow(new ApiException(code));
    mvc.perform(get("/api/v1/goals/" + id).header("X-Correlation-ID", "contract-error"))
        .andExpect(status().is(code.status()))
        .andExpect(content().contentType(MediaType.APPLICATION_PROBLEM_JSON))
        .andExpect(jsonPath("$.errorCode").value(code.code()))
        .andExpect(jsonPath("$.type").value("urn:kalash:error:" + code.code()))
        .andExpect(jsonPath("$.correlationId").value("contract-error"))
        .andExpect(jsonPath("$.timestamp").value("2026-10-27T20:00:00Z"))
        .andExpect(jsonPath("$.errors").doesNotExist());
  }

  @TestConfiguration(proxyBeanMethods = false)
  static class FixedTime {
    @Bean
    Clock clock() {
      return Clock.fixed(Instant.parse("2026-10-27T20:00:00Z"), ZoneId.of("Asia/Kolkata"));
    }
  }
}
