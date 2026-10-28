package com.kalash.goal.balance.service;

import com.kalash.goal.balance.api.BalanceAdjustmentRequest;
import com.kalash.goal.balance.api.GoalSnapshot;
import com.kalash.goal.common.error.ApiException;
import com.kalash.goal.common.error.ErrorCode;
import com.kalash.goal.goal.domain.Goal;
import com.kalash.goal.goal.domain.GoalStatus;
import com.kalash.goal.goal.service.GoalMutations;
import java.util.UUID;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;

/** Implements BR-10/11/12/13/14 with fresh-state retries owned by the goal feature. */
@Service
public class BalanceAdjustmentService {
  private static final Logger LOG = LoggerFactory.getLogger(BalanceAdjustmentService.class);
  private final GoalMutations mutations;
  private final StatusEvaluator statuses;

  /**
   * @param mutations goal-owned write boundary; never import another feature's repository
   * @param statuses shared state evaluator
   */
  public BalanceAdjustmentService(GoalMutations mutations, StatusEvaluator statuses) {
    this.mutations = mutations;
    this.statuses = statuses;
  }

  /**
   * @param id goal identity
   * @param request operation and signed whole-rupee delta
   * @return snapshot after the adjustment commits
   * @throws ApiException for invalid sign/overflow, forbidden operation or negative balance
   */
  public GoalSnapshot adjust(UUID id, BalanceAdjustmentRequest request) {
    Goal goal =
        mutations.update(
            id,
            current -> {
              switch (request.operation()) {
                case DEPOSIT -> {
                  if (current.status() != GoalStatus.ACTIVE)
                    throw new ApiException(ErrorCode.GOAL_009);
                  if (request.delta() <= 0) throw new ApiException(ErrorCode.COMMON_400);
                }
                case WITHDRAWAL -> {
                  if (current.status() == GoalStatus.CANCELLED)
                    throw new ApiException(ErrorCode.GOAL_010);
                  if (request.delta() >= 0) throw new ApiException(ErrorCode.COMMON_400);
                }
                case TRANSACTION_EDIT, TRANSACTION_DELETE -> {
                  if (current.status() != GoalStatus.ACTIVE)
                    throw new ApiException(ErrorCode.GOAL_011);
                  if (request.operation() == BalanceAdjustmentRequest.Operation.TRANSACTION_DELETE
                      && request.delta() == 0) throw new ApiException(ErrorCode.COMMON_400);
                }
              }
              long balance;
              try {
                balance = Math.addExact(current.balance(), request.delta());
              } catch (ArithmeticException overflow) {
                throw new ApiException(ErrorCode.COMMON_400);
              }
              if (balance < 0) throw new ApiException(ErrorCode.GOAL_012);
              current.changeBalance(balance);
              current.changeStatus(
                  statuses.evaluate(current.status(), balance, current.targetAmount()));
            });
    LOG.info("goal_balance_adjusted goalId={} operation={}", id, request.operation());
    return GoalSnapshot.from(goal);
  }
}
