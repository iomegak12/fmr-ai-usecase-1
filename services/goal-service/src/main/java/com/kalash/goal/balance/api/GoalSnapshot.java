package com.kalash.goal.balance.api;

import com.kalash.goal.goal.domain.Goal;
import com.kalash.goal.goal.domain.GoalStatus;
import java.util.UUID;

/** Internal state required by Transaction Service; deliberately excludes public insights. */
public record GoalSnapshot(UUID goalId, GoalStatus status, long balance, long targetAmount) {
  /**
   * @param goal current committed goal
   * @return LLD Section 14 snapshot
   */
  public static GoalSnapshot from(Goal goal) {
    return new GoalSnapshot(goal.goalId(), goal.status(), goal.balance(), goal.targetAmount());
  }
}
