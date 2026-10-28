package com.kalash.goal.goal.service;

import static org.assertj.core.api.Assertions.*;
import static org.mockito.Mockito.*;

import com.kalash.goal.common.error.ApiException;
import com.kalash.goal.common.error.ErrorCode;
import com.kalash.goal.goal.api.UpdateGoalRequest;
import com.kalash.goal.goal.domain.Goal;
import com.kalash.goal.goal.domain.GoalStatus;
import com.kalash.goal.goal.repository.GoalRepository;
import java.time.*;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;

class GoalRulesTest {
  private static final ZoneId IST = ZoneId.of("Asia/Kolkata");
  private final GoalRepository repository = mock(GoalRepository.class);

  @ParameterizedTest
  @ValueSource(strings = {"Goa", "  Goa", "Goa  ", "\tGoa\n", " Goa "})
  void whitespaceVariantsNormalizeToTheSameName(String supplied) {
    assertThat(rules(Instant.EPOCH).normalizeName(supplied)).isEqualTo("Goa");
  }

  @Test
  void innerWhitespaceAndCaseArePreservedAndHundredCharactersFit() {
    GoalRules rules = rules(Instant.EPOCH);
    assertThat(rules.normalizeName(" GOA  Trip ")).isEqualTo("GOA  Trip");
    assertThat(rules.normalizeName("x".repeat(100))).hasSize(100);
    expect(ErrorCode.COMMON_400, () -> rules.normalizeName(" "));
    expect(ErrorCode.COMMON_400, () -> rules.normalizeName(" " + "x".repeat(101) + " "));
  }

  @ParameterizedTest
  @ValueSource(strings = {"goa", "GOA", "gOa"})
  void caseVariantsUseTheCaseInsensitiveQueries(String name) {
    UUID self = UUID.randomUUID();
    when(repository.existsByNameIgnoreCase(name)).thenReturn(true);
    when(repository.existsByNameIgnoreCaseAndGoalIdNot(name, self)).thenReturn(false);
    GoalRules rules = rules(Instant.EPOCH);
    expect(ErrorCode.GOAL_002, () -> rules.ensureNameUnique(name, null));
    assertThatCode(() -> rules.ensureNameUnique(name, self)).doesNotThrowAnyException();
    // Case folding belongs to the IgnoreCase queries and the ux_goals_name_ci index, not here.
    verify(repository).existsByNameIgnoreCase(name);
    verify(repository).existsByNameIgnoreCaseAndGoalIdNot(name, self);
    verifyNoMoreInteractions(repository);
  }

  @Test
  void futureDateUsesTheIstCalendarDayNotUtc() {
    // 20:00 UTC on 27 October is already 01:30 IST on 28 October.
    GoalRules rules = rules(Instant.parse("2026-10-27T20:00:00Z"));
    expect(ErrorCode.GOAL_003, () -> rules.ensureFutureDate(LocalDate.of(2026, 10, 27)));
    expect(ErrorCode.GOAL_003, () -> rules.ensureFutureDate(LocalDate.of(2026, 10, 28)));
    assertThatCode(() -> rules.ensureFutureDate(LocalDate.of(2026, 10, 29)))
        .doesNotThrowAnyException();
  }

  @Test
  void tomorrowBecomesTodayAtIstMidnight() {
    LocalDate tomorrow = LocalDate.of(2026, 10, 29);
    assertThatCode(() -> rules(Instant.parse("2026-10-28T18:29:59Z")).ensureFutureDate(tomorrow))
        .doesNotThrowAnyException();
    expect(
        ErrorCode.GOAL_003,
        () -> rules(Instant.parse("2026-10-28T18:30:00Z")).ensureFutureDate(tomorrow));
  }

  @Test
  void targetMustStrictlyExceedBalance() {
    GoalRules rules = rules(Instant.EPOCH);
    assertThatCode(() -> rules.ensureTargetAboveBalance(101, 100)).doesNotThrowAnyException();
    expect(ErrorCode.GOAL_004, () -> rules.ensureTargetAboveBalance(100, 100));
    expect(ErrorCode.GOAL_004, () -> rules.ensureTargetAboveBalance(99, 100));
  }

  @Test
  void activeGoalsAcceptAnyEdit() {
    Goal goal = goal(GoalStatus.ACTIVE);
    GoalRules rules = rules(Instant.EPOCH);
    for (UpdateGoalRequest edit :
        new UpdateGoalRequest[] {
          new UpdateGoalRequest("New", null, null),
          new UpdateGoalRequest(null, 1L, null),
          new UpdateGoalRequest(null, null, LocalDate.of(2027, 5, 1))
        }) {
      assertThatCode(() -> rules.ensureEditAllowed(goal, edit)).doesNotThrowAnyException();
    }
  }

  @Test
  void achievedGoalsAcceptOnlyATargetRaise() {
    Goal goal = goal(GoalStatus.ACHIEVED);
    GoalRules rules = rules(Instant.EPOCH);
    assertThatCode(() -> rules.ensureEditAllowed(goal, new UpdateGoalRequest(null, 101L, null)))
        .doesNotThrowAnyException();
    for (UpdateGoalRequest edit :
        new UpdateGoalRequest[] {
          new UpdateGoalRequest(null, 100L, null),
          new UpdateGoalRequest(null, 99L, null),
          new UpdateGoalRequest("New", null, null),
          new UpdateGoalRequest(null, null, LocalDate.of(2027, 5, 1)),
          new UpdateGoalRequest("New", 200L, null),
          new UpdateGoalRequest(null, 200L, LocalDate.of(2027, 5, 1))
        }) {
      expect(ErrorCode.GOAL_005, () -> rules.ensureEditAllowed(goal, edit));
    }
  }

  @Test
  void cancelledGoalsAcceptNoEdit() {
    Goal goal = goal(GoalStatus.CANCELLED);
    expect(
        ErrorCode.GOAL_005,
        () ->
            rules(Instant.EPOCH).ensureEditAllowed(goal, new UpdateGoalRequest(null, 500L, null)));
  }

  private GoalRules rules(Instant now) {
    return new GoalRules(repository, Clock.fixed(now, IST));
  }

  private static Goal goal(GoalStatus status) {
    Goal goal =
        new Goal("Goal", 100, LocalDate.of(2027, 1, 1), OffsetDateTime.parse("2026-10-01T00:00Z"));
    goal.changeStatus(status);
    return goal;
  }

  private static void expect(
      ErrorCode code, org.assertj.core.api.ThrowableAssert.ThrowingCallable action) {
    assertThatThrownBy(action)
        .isInstanceOfSatisfying(
            ApiException.class, error -> assertThat(error.errorCode()).isEqualTo(code));
  }
}
