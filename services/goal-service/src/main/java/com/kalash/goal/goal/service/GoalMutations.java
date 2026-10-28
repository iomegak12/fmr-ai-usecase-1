package com.kalash.goal.goal.service;

import com.kalash.goal.common.error.ApiException;
import com.kalash.goal.common.error.ErrorCode;
import com.kalash.goal.goal.domain.Goal;
import com.kalash.goal.goal.repository.GoalRepository;
import java.time.Clock;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.UUID;
import java.util.function.Consumer;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.dao.OptimisticLockingFailureException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.TransactionDefinition;
import org.springframework.transaction.support.TransactionTemplate;

/**
 * Shared goal-owned write boundary: each optimistic retry rereads and revalidates in a fresh
 * transaction.
 */
@Service
public class GoalMutations {
  private static final Logger LOG = LoggerFactory.getLogger(GoalMutations.class);
  private final GoalRepository repository;
  private final Clock clock;
  private final TransactionTemplate transaction;

  /**
   * @param repository goal-owned persistence
   * @param clock injected timestamp clock
   * @param manager transaction manager; every attempt uses REQUIRES_NEW
   */
  public GoalMutations(GoalRepository repository, Clock clock, PlatformTransactionManager manager) {
    this.repository = repository;
    this.clock = clock;
    this.transaction = new TransactionTemplate(manager);
    this.transaction.setPropagationBehavior(TransactionDefinition.PROPAGATION_REQUIRES_NEW);
  }

  /**
   * @param id goal identity
   * @param change validated mutation, rerun against freshly loaded state on every retry
   * @return committed goal
   * @throws ApiException GOAL-001 if missing, or COMMON-409 after three retries
   */
  public Goal update(UUID id, Consumer<Goal> change) {
    return execute(id, change, false);
  }

  /**
   * @param id goal identity
   * @param validate rule check rerun before deletion on every attempt
   * @throws ApiException GOAL-001 if missing, or COMMON-409 after three retries
   */
  public void delete(UUID id, Consumer<Goal> validate) {
    execute(id, validate, true);
  }

  private Goal execute(UUID id, Consumer<Goal> change, boolean delete) {
    for (int attempt = 0; attempt <= 3; attempt++) {
      try {
        return transaction.execute(
            status -> {
              Goal goal =
                  repository.findById(id).orElseThrow(() -> new ApiException(ErrorCode.GOAL_001));
              change.accept(goal);
              if (delete) {
                repository.delete(goal);
                repository.flush();
              } else {
                goal.touch(OffsetDateTime.ofInstant(clock.instant(), ZoneOffset.UTC));
                repository.saveAndFlush(goal);
              }
              return goal;
            });
      } catch (OptimisticLockingFailureException conflict) {
        LOG.warn("optimistic_lock_conflict goalId={} attempt={}", id, attempt + 1);
        if (attempt == 3) throw new ApiException(ErrorCode.COMMON_409);
      }
    }
    throw new IllegalStateException("Unreachable retry boundary");
  }
}
