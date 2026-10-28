package com.kalash.goal.goal.service;

import static org.assertj.core.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

import com.kalash.goal.common.error.ApiException;
import com.kalash.goal.common.error.ErrorCode;
import com.kalash.goal.goal.domain.Goal;
import com.kalash.goal.goal.repository.GoalRepository;
import java.time.*;
import java.util.Optional;
import java.util.UUID;
import java.util.concurrent.atomic.AtomicInteger;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.dao.OptimisticLockingFailureException;
import org.springframework.transaction.*;
import org.springframework.transaction.support.SimpleTransactionStatus;

class GoalMutationsTest {
  private final GoalRepository repository = mock(GoalRepository.class);
  private final PlatformTransactionManager manager = mock(PlatformTransactionManager.class);
  private final Clock clock = Clock.fixed(Instant.parse("2026-10-27T00:00:00Z"), ZoneOffset.UTC);
  private final GoalMutations mutations = new GoalMutations(repository, clock, manager);
  private final UUID id = UUID.randomUUID();
  private final AtomicInteger loads = new AtomicInteger();

  @BeforeEach
  void setup() {
    when(manager.getTransaction(any()))
        .thenAnswer(
            call -> {
              TransactionDefinition definition = call.getArgument(0);
              assertThat(definition.getPropagationBehavior())
                  .isEqualTo(TransactionDefinition.PROPAGATION_REQUIRES_NEW);
              return new SimpleTransactionStatus();
            });
    when(repository.findById(id))
        .thenAnswer(
            ignored -> {
              loads.incrementAndGet();
              return Optional.of(
                  new Goal("Goal", 100, LocalDate.of(2027, 1, 1), OffsetDateTime.now(clock)));
            });
  }

  @Test
  void threeRetriesReloadAndRevalidateThenCommitOnlySuccessfulAttempt() {
    when(repository.saveAndFlush(any()))
        .thenThrow(new OptimisticLockingFailureException("conflict"))
        .thenThrow(new OptimisticLockingFailureException("conflict"))
        .thenThrow(new OptimisticLockingFailureException("conflict"))
        .thenAnswer(call -> call.getArgument(0));
    Goal result = mutations.update(id, goal -> goal.changeBalance(goal.balance() + 10));
    assertThat(result.balance()).isEqualTo(10);
    assertThat(loads).hasValue(4);
    verify(manager, times(3)).rollback(any());
    verify(manager).commit(any());
  }

  @Test
  void exhaustedRetriesBecomeCommon409() {
    when(repository.saveAndFlush(any()))
        .thenThrow(new OptimisticLockingFailureException("conflict"));
    assertThatThrownBy(() -> mutations.update(id, goal -> goal.changeBalance(10)))
        .isInstanceOfSatisfying(
            ApiException.class,
            error -> assertThat(error.errorCode()).isEqualTo(ErrorCode.COMMON_409));
    assertThat(loads).hasValue(4);
    verify(manager, times(4)).rollback(any());
    verify(manager, never()).commit(any());
  }

  @Test
  void commitTimeConflictAlsoRetries() {
    doThrow(new OptimisticLockingFailureException("commit conflict"))
        .doNothing()
        .when(manager)
        .commit(any());
    mutations.update(id, goal -> goal.changeBalance(5));
    assertThat(loads).hasValue(2);
  }

  @Test
  void deletedBetweenAttemptsBecomesNotFoundWithoutFurtherRetries() {
    when(repository.findById(id)).thenReturn(Optional.empty());
    assertThatThrownBy(() -> mutations.update(id, goal -> {}))
        .isInstanceOfSatisfying(
            ApiException.class,
            error -> assertThat(error.errorCode()).isEqualTo(ErrorCode.GOAL_001));
    verify(repository, times(1)).findById(id);
  }

  @Test
  void nonOptimisticFailuresAreNotRetriedAndDeletionRetriesFreshState() {
    assertThatThrownBy(
            () ->
                mutations.update(
                    id,
                    goal -> {
                      throw new ApiException(ErrorCode.GOAL_005);
                    }))
        .isInstanceOf(ApiException.class);
    verify(repository, times(1)).findById(id);
    doThrow(new OptimisticLockingFailureException("delete conflict"))
        .doNothing()
        .when(repository)
        .flush();
    mutations.delete(id, goal -> {});
    verify(repository, times(2)).delete(any());
  }
}
