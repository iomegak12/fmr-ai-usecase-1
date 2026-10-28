package com.kalash.goal.goal.service;

import com.kalash.goal.balance.service.StatusEvaluator;
import com.kalash.goal.common.error.ApiException;
import com.kalash.goal.common.error.ErrorCode;
import com.kalash.goal.goal.api.*;
import com.kalash.goal.goal.domain.Goal;
import com.kalash.goal.goal.domain.GoalStatus;
import com.kalash.goal.goal.repository.GoalRepository;
import com.kalash.goal.insights.InsightsCalculator;
import java.time.Clock;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.UUID;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/** Goal lifecycle orchestration for BR-01 through BR-06 and BR-15 through BR-20. */
@Service
public class GoalService {
  private static final Logger LOG = LoggerFactory.getLogger(GoalService.class);
  private final GoalRepository repository;
  private final GoalRules rules;
  private final GoalMutations mutations;
  private final InsightsCalculator insights;
  private final StatusEvaluator statuses;
  private final Clock clock;

  /**
   * @param repository goal-owned persistence
   * @param rules business validation
   * @param mutations independent transaction/retry boundary
   * @param insights read-time guidance
   * @param statuses lifecycle evaluator
   * @param clock injected time source
   */
  public GoalService(
      GoalRepository repository,
      GoalRules rules,
      GoalMutations mutations,
      InsightsCalculator insights,
      StatusEvaluator statuses,
      Clock clock) {
    this.repository = repository;
    this.rules = rules;
    this.mutations = mutations;
    this.insights = insights;
    this.statuses = statuses;
    this.clock = clock;
  }

  /**
   * @param request validated create fields
   * @return the new zero-balance Active goal
   * @throws ApiException on duplicate name or invalid business date
   */
  @Transactional
  public GoalResponse create(CreateGoalRequest request) {
    String name = rules.normalizeName(request.name());
    rules.ensureNameUnique(name, null);
    rules.ensureFutureDate(request.targetDate());
    Goal goal =
        repository.saveAndFlush(
            new Goal(
                name,
                request.targetAmount(),
                request.targetDate(),
                OffsetDateTime.ofInstant(clock.instant(), ZoneOffset.UTC)));
    LOG.info("goal_created goalId={} operation=CREATE", goal.goalId());
    return response(goal);
  }

  /**
   * @param id goal identity
   * @return goal details with current insights
   * @throws ApiException GOAL-001 when missing
   */
  @Transactional(readOnly = true)
  public GoalResponse get(UUID id) {
    return response(require(id));
  }

  /**
   * @param page zero-based page
   * @param size size from 1 through 100
   * @return BR-25 sorted overview including all lifecycle states
   */
  @Transactional(readOnly = true)
  public PageResponse<GoalResponse> list(int page, int size) {
    return PageResponse.from(
        repository
            .findAllByOrderByTargetDateAscCreatedAtAscGoalIdAsc(PageRequest.of(page, size))
            .map(this::response));
  }

  /**
   * @param id goal identity
   * @param request validated partial edit
   * @return the updated goal; raising an Achieved target reactivates it
   * @throws ApiException on a forbidden edit or business-rule violation
   */
  public GoalResponse update(UUID id, UpdateGoalRequest request) {
    Goal goal =
        mutations.update(
            id,
            current -> {
              rules.ensureEditAllowed(current, request);
              String name = request.name() == null ? null : rules.normalizeName(request.name());
              if (name != null) rules.ensureNameUnique(name, id);
              if (request.targetDate() != null) rules.ensureFutureDate(request.targetDate());
              if (request.targetAmount() != null)
                rules.ensureTargetAboveBalance(request.targetAmount(), current.balance());
              current.edit(name, request.targetAmount(), request.targetDate());
              current.changeStatus(
                  statuses.evaluate(current.status(), current.balance(), current.targetAmount()));
            });
    LOG.info("goal_updated goalId={} operation=UPDATE", id);
    return response(goal);
  }

  /**
   * @param id goal identity
   * @return cancelled read-only goal with null insights
   * @throws ApiException GOAL-006/007 unless Active with zero balance
   */
  public GoalResponse cancel(UUID id) {
    Goal goal =
        mutations.update(
            id,
            current -> {
              if (current.status() != GoalStatus.ACTIVE) throw new ApiException(ErrorCode.GOAL_006);
              if (current.balance() != 0) throw new ApiException(ErrorCode.GOAL_007);
              current.changeStatus(GoalStatus.CANCELLED);
            });
    LOG.info("goal_cancelled goalId={} operation=CANCEL", id);
    return response(goal);
  }

  /**
   * @param id goal identity
   * @return the goal for the internal snapshot; no cross-feature repository access
   * @throws ApiException GOAL-001 if missing
   */
  @Transactional(readOnly = true)
  public Goal require(UUID id) {
    return repository.findById(id).orElseThrow(() -> new ApiException(ErrorCode.GOAL_001));
  }

  /**
   * @param id goal identity
   * @throws ApiException GOAL-008 unless Cancelled, or GOAL-001 if missing
   */
  public void deleteCancelled(UUID id) {
    mutations.delete(
        id,
        goal -> {
          if (goal.status() != GoalStatus.CANCELLED) throw new ApiException(ErrorCode.GOAL_008);
        });
    LOG.info("goal_deleted goalId={} operation=DELETE", id);
  }

  private GoalResponse response(Goal goal) {
    return GoalResponse.from(goal, insights.calculate(goal));
  }
}
