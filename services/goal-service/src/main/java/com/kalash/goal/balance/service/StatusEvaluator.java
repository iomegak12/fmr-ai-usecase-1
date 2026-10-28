package com.kalash.goal.balance.service;

import com.kalash.goal.goal.domain.GoalStatus;
import org.springframework.stereotype.Component;

/** Centralizes BR-15/16 transitions while preserving terminal cancellation (BR-19). */
@Component
public class StatusEvaluator {
  /**
   * @param current current status
   * @param balance validated nonnegative balance
   * @param target validated positive target
   * @return evaluated lifecycle state
   */
  public GoalStatus evaluate(GoalStatus current, long balance, long target) {
    return current == GoalStatus.CANCELLED
        ? current
        : balance >= target ? GoalStatus.ACHIEVED : GoalStatus.ACTIVE;
  }
}
