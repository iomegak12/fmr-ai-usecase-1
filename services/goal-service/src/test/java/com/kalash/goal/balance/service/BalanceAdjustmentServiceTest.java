package com.kalash.goal.balance.service;

import static org.assertj.core.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

import com.kalash.goal.balance.api.BalanceAdjustmentRequest;
import com.kalash.goal.balance.api.BalanceAdjustmentRequest.Operation;
import com.kalash.goal.common.error.ApiException;
import com.kalash.goal.common.error.ErrorCode;
import com.kalash.goal.goal.domain.Goal;
import com.kalash.goal.goal.domain.GoalStatus;
import com.kalash.goal.goal.service.GoalMutations;
import java.time.*;
import java.util.function.Consumer;
import java.util.stream.Stream;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.*;

class BalanceAdjustmentServiceTest {
  private final GoalMutations mutations = mock(GoalMutations.class);
  private final StatusEvaluator evaluator = new StatusEvaluator();
  private final BalanceAdjustmentService service =
      new BalanceAdjustmentService(mutations, evaluator);
  private Goal goal;

  @BeforeEach
  void setup() {
    goal =
        new Goal("Goal", 100, LocalDate.of(2027, 1, 1), OffsetDateTime.parse("2026-01-01T00:00Z"));
    goal.changeBalance(50);
    when(mutations.update(eq(goal.goalId()), any()))
        .thenAnswer(
            call -> {
              Consumer<Goal> change = call.getArgument(1);
              change.accept(goal);
              return goal;
            });
  }

  static Stream<Arguments> operationsAndStatuses() {
    return Stream.of(Operation.values())
        .flatMap(
            operation ->
                Stream.of(GoalStatus.values()).map(status -> Arguments.of(operation, status)));
  }

  @ParameterizedTest
  @MethodSource("operationsAndStatuses")
  void allTwelveStatusOperationCombinations(Operation operation, GoalStatus status) {
    goal.changeStatus(status);
    long delta = operation == Operation.WITHDRAWAL ? -1 : 1;
    ErrorCode rejection =
        switch (operation) {
          case DEPOSIT -> status != GoalStatus.ACTIVE ? ErrorCode.GOAL_009 : null;
          case WITHDRAWAL -> status == GoalStatus.CANCELLED ? ErrorCode.GOAL_010 : null;
          case TRANSACTION_EDIT, TRANSACTION_DELETE ->
              status != GoalStatus.ACTIVE ? ErrorCode.GOAL_011 : null;
        };
    if (rejection == null) {
      assertThat(
              service
                  .adjust(goal.goalId(), new BalanceAdjustmentRequest(operation, delta))
                  .balance())
          .isEqualTo(50 + delta);
    } else {
      expect(
          rejection,
          () -> service.adjust(goal.goalId(), new BalanceAdjustmentRequest(operation, delta)));
    }
  }

  @ParameterizedTest
  @CsvSource({"DEPOSIT,0", "DEPOSIT,-1", "WITHDRAWAL,0", "WITHDRAWAL,1", "TRANSACTION_DELETE,0"})
  void invalidSignsAreBadRequests(Operation operation, long delta) {
    expect(
        ErrorCode.COMMON_400,
        () -> service.adjust(goal.goalId(), new BalanceAdjustmentRequest(operation, delta)));
  }

  @Test
  void editAllowsZeroAndBothSignsButBalanceCannotBecomeNegative() {
    for (long delta : new long[] {0, 1, -1}) {
      service.adjust(
          goal.goalId(), new BalanceAdjustmentRequest(Operation.TRANSACTION_EDIT, delta));
    }
    expect(
        ErrorCode.GOAL_012,
        () ->
            service.adjust(
                goal.goalId(), new BalanceAdjustmentRequest(Operation.WITHDRAWAL, -51L)));
    expect(
        ErrorCode.GOAL_012,
        () ->
            service.adjust(
                goal.goalId(), new BalanceAdjustmentRequest(Operation.TRANSACTION_DELETE, -51L)));
    expect(
        ErrorCode.GOAL_012,
        () ->
            service.adjust(
                goal.goalId(),
                new BalanceAdjustmentRequest(Operation.TRANSACTION_EDIT, Long.MIN_VALUE)));
    assertThat(
            service
                .adjust(goal.goalId(), new BalanceAdjustmentRequest(Operation.WITHDRAWAL, -50L))
                .balance())
        .isZero();
  }

  @Test
  void reachingOrOvershootingTargetAchievesAndWithdrawalReactivates() {
    assertThat(
            service
                .adjust(goal.goalId(), new BalanceAdjustmentRequest(Operation.DEPOSIT, 50L))
                .status())
        .isEqualTo(GoalStatus.ACHIEVED);
    service.adjust(goal.goalId(), new BalanceAdjustmentRequest(Operation.WITHDRAWAL, -1L));
    assertThat(goal.status()).isEqualTo(GoalStatus.ACTIVE);
    assertThat(
            service
                .adjust(goal.goalId(), new BalanceAdjustmentRequest(Operation.DEPOSIT, 100L))
                .balance())
        .isEqualTo(199);
    assertThat(goal.status()).isEqualTo(GoalStatus.ACHIEVED);
    assertThat(evaluator.evaluate(GoalStatus.CANCELLED, 100, 50)).isEqualTo(GoalStatus.CANCELLED);
  }

  @Test
  void overflowIsRejectedWithoutWrappingBalance() {
    goal.changeBalance(Long.MAX_VALUE);
    expect(
        ErrorCode.COMMON_400,
        () -> service.adjust(goal.goalId(), new BalanceAdjustmentRequest(Operation.DEPOSIT, 1L)));
    assertThat(goal.balance()).isEqualTo(Long.MAX_VALUE);
  }

  private void expect(
      ErrorCode code, org.assertj.core.api.ThrowableAssert.ThrowingCallable action) {
    assertThatThrownBy(action)
        .isInstanceOfSatisfying(
            ApiException.class, error -> assertThat(error.errorCode()).isEqualTo(code));
  }
}
