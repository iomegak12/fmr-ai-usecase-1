package com.kalash.goal.goal.service;

import static org.assertj.core.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

import com.kalash.goal.balance.service.StatusEvaluator;
import com.kalash.goal.common.error.ApiException;
import com.kalash.goal.common.error.ErrorCode;
import com.kalash.goal.goal.api.*;
import com.kalash.goal.goal.domain.Goal;
import com.kalash.goal.goal.domain.GoalStatus;
import com.kalash.goal.goal.repository.GoalRepository;
import com.kalash.goal.insights.InsightsCalculator;
import java.time.*;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.EnumSource;
import org.springframework.data.domain.PageImpl;
import org.springframework.data.domain.PageRequest;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.support.SimpleTransactionStatus;

class GoalServiceTest {
  private final Clock clock =
      Clock.fixed(Instant.parse("2026-10-27T20:00:00Z"), ZoneId.of("Asia/Kolkata"));
  private final GoalRepository repository = mock(GoalRepository.class);
  private final PlatformTransactionManager manager = mock(PlatformTransactionManager.class);
  private final GoalRules rules = new GoalRules(repository, clock);
  private final GoalService service =
      new GoalService(
          repository,
          rules,
          new GoalMutations(repository, clock, manager),
          new InsightsCalculator(clock),
          new StatusEvaluator(),
          clock);
  private Goal goal;

  @BeforeEach
  void setup() {
    goal =
        new Goal(
            "Original", 100, LocalDate.of(2027, 1, 1), OffsetDateTime.parse("2026-10-01T00:00Z"));
    when(repository.findById(goal.goalId())).thenAnswer(ignored -> Optional.of(goal));
    when(repository.saveAndFlush(any())).thenAnswer(call -> call.getArgument(0));
    when(manager.getTransaction(any())).thenAnswer(ignored -> new SimpleTransactionStatus());
  }

  @Test
  void timestampsMatchPostgresMicrosecondPrecisionBeforeFirstResponse() {
    OffsetDateTime precise = OffsetDateTime.parse("2026-10-28T00:00:00.123456789Z");
    Goal created = new Goal("Precision", 1, LocalDate.of(2027, 1, 1), precise);
    assertThat(created.createdAt().getNano()).isEqualTo(123456000);
    assertThat(created.updatedAt()).isEqualTo(created.createdAt());
    created.touch(precise.plusSeconds(1));
    assertThat(created.updatedAt().getNano()).isEqualTo(123456000);
  }

  @Test
  void createsTrimmedActiveGoalWithZeroBalanceAndUtcTimestamps() {
    GoalResponse result =
        service.create(new CreateGoalRequest("  Goa  ", 100L, LocalDate.of(2027, 1, 1)));
    assertThat(result.name()).isEqualTo("Goa");
    assertThat(result.balance()).isZero();
    assertThat(result.status()).isEqualTo(GoalStatus.ACTIVE);
    assertThat(result.createdAt().toInstant()).isEqualTo(clock.instant());
    assertThat(result.createdAt().getOffset()).isEqualTo(ZoneOffset.UTC);
    assertThat(result.updatedAt()).isEqualTo(result.createdAt());
    verify(repository).existsByNameIgnoreCase("Goa");
  }

  @Test
  void duplicateAndBlankNamesAreRejected() {
    when(repository.existsByNameIgnoreCase("Goa")).thenReturn(true);
    expect(
        ErrorCode.GOAL_002,
        () -> service.create(new CreateGoalRequest(" Goa ", 1L, LocalDate.of(2027, 1, 1))));
    expect(ErrorCode.COMMON_400, () -> rules.normalizeName("\u2003"));
    expect(ErrorCode.COMMON_400, () -> rules.normalizeName("x".repeat(101)));
    when(repository.existsByNameIgnoreCaseAndGoalIdNot("Other", goal.goalId())).thenReturn(true);
    expect(
        ErrorCode.GOAL_002,
        () -> service.update(goal.goalId(), new UpdateGoalRequest("Other", null, null)));
  }

  @Test
  void todayUsesIstAndOnlySuppliedDatesAreRevalidated() {
    for (LocalDate date : List.of(LocalDate.of(2026, 10, 27), LocalDate.of(2026, 10, 28))) {
      expect(ErrorCode.GOAL_003, () -> service.create(new CreateGoalRequest("Name", 1L, date)));
    }
    rules.ensureFutureDate(LocalDate.of(2026, 10, 29));
    goal.edit(null, null, LocalDate.of(2026, 10, 1));
    assertThat(service.update(goal.goalId(), new UpdateGoalRequest("Renamed", null, null)).name())
        .isEqualTo("Renamed");
    expect(
        ErrorCode.GOAL_003,
        () ->
            service.update(
                goal.goalId(), new UpdateGoalRequest(null, null, LocalDate.of(2026, 10, 28))));
  }

  @Test
  void updatesPermittedFieldsAndPreservesCreationTimestamp() {
    OffsetDateTime original = goal.createdAt();
    GoalResponse response =
        service.update(
            goal.goalId(), new UpdateGoalRequest(" New ", 150L, LocalDate.of(2027, 3, 1)));
    assertThat(response.name()).isEqualTo("New");
    assertThat(response.targetAmount()).isEqualTo(150);
    assertThat(response.targetDate()).isEqualTo(LocalDate.of(2027, 3, 1));
    assertThat(response.createdAt()).isEqualTo(original);
    assertThat(response.updatedAt().toInstant()).isEqualTo(clock.instant());
    goal.changeBalance(150);
    expect(
        ErrorCode.GOAL_004,
        () -> service.update(goal.goalId(), new UpdateGoalRequest(null, 150L, null)));
    expect(
        ErrorCode.GOAL_004,
        () -> service.update(goal.goalId(), new UpdateGoalRequest(null, 100L, null)));
  }

  @Test
  void achievedAllowsOnlyRaisingTargetAboveCurrentBalance() {
    goal.changeBalance(120);
    goal.changeStatus(GoalStatus.ACHIEVED);
    for (UpdateGoalRequest edit :
        List.of(
            new UpdateGoalRequest("New", null, null),
            new UpdateGoalRequest(null, null, LocalDate.of(2027, 5, 1)),
            new UpdateGoalRequest(null, 100L, null),
            new UpdateGoalRequest(null, 99L, null),
            new UpdateGoalRequest("New", 200L, null))) {
      expect(ErrorCode.GOAL_005, () -> service.update(goal.goalId(), edit));
    }
    expect(
        ErrorCode.GOAL_004,
        () -> service.update(goal.goalId(), new UpdateGoalRequest(null, 120L, null)));
    GoalResponse raised = service.update(goal.goalId(), new UpdateGoalRequest(null, 121L, null));
    assertThat(raised.status()).isEqualTo(GoalStatus.ACTIVE);
  }

  @Test
  void cancellationRequiresActiveAndZeroBalanceThenPreventsEditing() {
    goal.changeBalance(1);
    expect(ErrorCode.GOAL_007, () -> service.cancel(goal.goalId()));
    goal.changeBalance(0);
    GoalResponse cancelled = service.cancel(goal.goalId());
    assertThat(cancelled.status()).isEqualTo(GoalStatus.CANCELLED);
    assertThat(cancelled.insights()).isNull();
    expect(
        ErrorCode.GOAL_005,
        () -> service.update(goal.goalId(), new UpdateGoalRequest("New", null, null)));
    expect(ErrorCode.GOAL_006, () -> service.cancel(goal.goalId()));
    goal.changeStatus(GoalStatus.ACHIEVED);
    expect(ErrorCode.GOAL_006, () -> service.cancel(goal.goalId()));
  }

  @ParameterizedTest
  @EnumSource(GoalStatus.class)
  void deletionRequiresCancelledAndFlushes(GoalStatus status) {
    goal.changeStatus(status);
    if (status == GoalStatus.CANCELLED) {
      service.deleteCancelled(goal.goalId());
      verify(repository).delete(goal);
      verify(repository).flush();
    } else {
      expect(ErrorCode.GOAL_008, () -> service.deleteCancelled(goal.goalId()));
      verify(repository, never()).delete(any());
    }
  }

  @Test
  void readsUseFreshInsightsAndStableSortedPageQuery() {
    var pageable = PageRequest.of(1, 2);
    when(repository.findAllByOrderByTargetDateAscCreatedAtAscGoalIdAsc(pageable))
        .thenReturn(new PageImpl<>(List.of(goal), pageable, 3));
    var result = service.list(1, 2);
    assertThat(result.page()).isEqualTo(1);
    assertThat(result.size()).isEqualTo(2);
    assertThat(result.totalElements()).isEqualTo(3);
    assertThat(result.totalPages()).isEqualTo(2);
    assertThat(result.content().getFirst()).isEqualTo(service.get(goal.goalId()));
    assertThat(service.require(goal.goalId())).isSameAs(goal);
    UUID missing = UUID.randomUUID();
    expect(ErrorCode.GOAL_001, () -> service.get(missing));
    expect(
        ErrorCode.GOAL_001,
        () -> service.update(missing, new UpdateGoalRequest("New", null, null)));
    expect(ErrorCode.GOAL_001, () -> service.cancel(missing));
    expect(ErrorCode.GOAL_001, () -> service.deleteCancelled(missing));
  }

  private void expect(
      ErrorCode code, org.assertj.core.api.ThrowableAssert.ThrowingCallable action) {
    assertThatThrownBy(action)
        .isInstanceOfSatisfying(
            ApiException.class, error -> assertThat(error.errorCode()).isEqualTo(code));
  }
}
