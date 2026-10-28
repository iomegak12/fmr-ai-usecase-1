package com.kalash.goal.insights;

import static org.assertj.core.api.Assertions.assertThat;

import com.kalash.goal.goal.domain.Goal;
import com.kalash.goal.goal.domain.GoalStatus;
import java.math.BigDecimal;
import java.time.*;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.CsvSource;

class InsightsCalculatorTest {
  private static final ZoneId IST = ZoneId.of("Asia/Kolkata");

  @ParameterizedTest
  @CsvSource({
    "0,10000,2026-11-01,2027-02-01,2026-11-01,0.0,10000,3334,false,false,ACTIVE",
    "3000,10000,2026-11-01,2027-03-01,2027-01-01,30.0,7000,3500,true,false,ACTIVE",
    "6000,10000,2026-11-01,2027-03-01,2027-01-01,60.0,4000,2000,false,false,ACTIVE",
    "8000,10000,2026-11-01,2026-12-20,2026-12-05,80.0,2000,2000,false,false,ACTIVE",
    "5000,10000,2026-11-01,2026-12-01,2026-12-10,50.0,5000,5000,true,true,ACTIVE",
    "12000,10000,2026-11-01,2027-03-01,2027-01-01,120.0,0,0,false,false,ACHIEVED",
    "9996,10000,2026-11-01,2027-03-01,2027-01-01,99.9,4,2,false,false,ACTIVE"
  })
  void allSevenLldExamples(
      long balance,
      long target,
      LocalDate created,
      LocalDate deadline,
      LocalDate today,
      BigDecimal progress,
      long remaining,
      long monthly,
      boolean off,
      boolean overdue,
      GoalStatus status) {
    Goal goal = goal(balance, target, created, deadline, status);
    assertThat(calculator(today).calculate(goal))
        .isEqualTo(new Insights(progress, remaining, monthly, off, overdue));
  }

  @Test
  void targetDayIsNotOverdueAndCreationDayNeverOffTrack() {
    Goal goal = goal(0, 10, LocalDate.of(2026, 1, 1), LocalDate.of(2026, 2, 1), GoalStatus.ACTIVE);
    Insights onTarget = calculator(goal.targetDate()).calculate(goal);
    assertThat(onTarget.overdue()).isFalse();
    assertThat(onTarget.suggestedMonthlySaving()).isEqualTo(10);
    assertThat(calculator(LocalDate.of(2026, 1, 1)).calculate(goal).offTrack()).isFalse();
  }

  @Test
  void cancelledHasNoInsightsAndAchievedHasNoIndicatorsEvenPastDate() {
    Goal goal =
        goal(20, 10, LocalDate.of(2026, 1, 1), LocalDate.of(2026, 2, 1), GoalStatus.ACHIEVED);
    Insights result = calculator(LocalDate.of(2026, 3, 1)).calculate(goal);
    assertThat(result.remainingAmount()).isZero();
    assertThat(result.suggestedMonthlySaving()).isZero();
    assertThat(result.offTrack()).isFalse();
    assertThat(result.overdue()).isFalse();
    goal.changeStatus(GoalStatus.CANCELLED);
    assertThat(calculator(LocalDate.of(2026, 3, 1)).calculate(goal)).isNull();
  }

  @Test
  void targetEditUsesOriginalCreationDateAndUnroundedFractions() {
    LocalDate created = LocalDate.of(2026, 1, 1);
    Goal goal = goal(1, 3, created, created.plusDays(3), GoalStatus.ACTIVE);
    // Both exact fractions equal 1/3; rounded progress is 33.3, but not off track.
    assertThat(calculator(created.plusDays(1)).calculate(goal).offTrack()).isFalse();
    goal.edit(null, null, created.plusDays(2));
    assertThat(calculator(created.plusDays(1)).calculate(goal).offTrack()).isTrue();
    assertThat(goal.createdAt().toLocalDate()).isEqualTo(created.minusDays(1));
  }

  @Test
  void largeValuesNeverOverflowAndRoundingIsDown() {
    LocalDate start = LocalDate.of(2026, 1, 1);
    Goal goal = goal(0, Long.MAX_VALUE, start, start.plusMonths(3), GoalStatus.ACTIVE);
    assertThat(calculator(start).calculate(goal).suggestedMonthlySaving())
        .isEqualTo(3074457345618258603L);
    goal.changeBalance(Long.MAX_VALUE);
    goal.edit(null, 1L, null);
    assertThat(calculator(start).calculate(goal).progressPercent())
        .isEqualByComparingTo("922337203685477580700.0");
  }

  @Test
  void istDayAndCalendarMonthsRatherThanThirtyDayBuckets() {
    Goal goal =
        goal(0, 100, LocalDate.of(2026, 12, 31), LocalDate.of(2027, 3, 1), GoalStatus.ACTIVE);
    Insights result =
        new InsightsCalculator(Clock.fixed(Instant.parse("2026-12-31T20:00:00Z"), IST))
            .calculate(goal);
    assertThat(result.suggestedMonthlySaving()).isEqualTo(50);
    assertThat(result.offTrack()).isTrue();
  }

  private InsightsCalculator calculator(LocalDate today) {
    return new InsightsCalculator(Clock.fixed(today.atStartOfDay(IST).toInstant(), IST));
  }

  private Goal goal(
      long balance, long target, LocalDate created, LocalDate deadline, GoalStatus status) {
    Goal goal =
        new Goal(
            "test",
            target,
            deadline,
            created.atStartOfDay(IST).toOffsetDateTime().withOffsetSameInstant(ZoneOffset.UTC));
    goal.changeBalance(balance);
    goal.changeStatus(status);
    return goal;
  }
}
