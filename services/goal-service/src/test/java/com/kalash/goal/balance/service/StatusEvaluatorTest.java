package com.kalash.goal.balance.service;

import static org.assertj.core.api.Assertions.assertThat;

import com.kalash.goal.goal.domain.GoalStatus;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.CsvSource;

class StatusEvaluatorTest {
  private final StatusEvaluator evaluator = new StatusEvaluator();

  @ParameterizedTest(name = "{0} with balance {1} and target {2} -> {3}")
  @CsvSource({
    // Active -> Achieved when the balance reaches or passes the target (BR-15).
    "ACTIVE, 99, 100, ACTIVE",
    "ACTIVE, 100, 100, ACHIEVED",
    "ACTIVE, 101, 100, ACHIEVED",
    // Achieved -> Active after a withdrawal or a target raise (BR-16).
    "ACHIEVED, 100, 100, ACHIEVED",
    "ACHIEVED, 99, 100, ACTIVE",
    "ACHIEVED, 100, 101, ACTIVE",
    "ACHIEVED, 0, 100, ACTIVE",
    // Cancelled is terminal whatever the amounts (BR-19).
    "CANCELLED, 0, 100, CANCELLED",
    "CANCELLED, 100, 100, CANCELLED",
    "CANCELLED, 101, 100, CANCELLED"
  })
  void transitions(GoalStatus current, long balance, long target, GoalStatus expected) {
    assertThat(evaluator.evaluate(current, balance, target)).isEqualTo(expected);
  }
}
