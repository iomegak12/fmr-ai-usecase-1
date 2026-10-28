package com.kalash.goal.insights;

import com.kalash.goal.goal.domain.Goal;
import com.kalash.goal.goal.domain.GoalStatus;
import java.math.BigDecimal;
import java.math.BigInteger;
import java.math.RoundingMode;
import java.time.Clock;
import java.time.LocalDate;
import java.time.Period;
import java.time.temporal.ChronoUnit;
import org.springframework.stereotype.Component;

/** Pure read-time calculations implementing BR-21/22/23/24 without floating-point loss. */
@Component
public class InsightsCalculator {
  private final Clock clock;

  /**
   * @param clock business timezone clock, fixed in tests
   */
  public InsightsCalculator(Clock clock) {
    this.clock = clock;
  }

  /**
   * @param goal validated persisted goal
   * @return uncapped savings guidance, or null for a Cancelled goal
   */
  public Insights calculate(Goal goal) {
    if (goal.status() == GoalStatus.CANCELLED) return null;
    LocalDate today = LocalDate.now(clock);
    LocalDate created = goal.createdAt().atZoneSameInstant(clock.getZone()).toLocalDate();
    long remaining = Math.max(goal.targetAmount() - goal.balance(), 0);
    BigDecimal progress =
        BigDecimal.valueOf(goal.balance())
            .multiply(BigDecimal.valueOf(100))
            .divide(BigDecimal.valueOf(goal.targetAmount()), 1, RoundingMode.DOWN);
    boolean active = goal.status() == GoalStatus.ACTIVE;
    boolean overdue = active && today.isAfter(goal.targetDate()) && remaining > 0;
    long months = Period.between(today, goal.targetDate()).toTotalMonths();
    long monthly =
        remaining == 0
            ? 0
            : overdue || months < 1
                ? remaining
                : remaining / months + (remaining % months == 0 ? 0 : 1);
    long duration = ChronoUnit.DAYS.between(created, goal.targetDate());
    long elapsed = Math.max(0, Math.min(ChronoUnit.DAYS.between(created, today), duration));
    // Cross-multiply the raw fractions so rounding never affects off-track decisions.
    boolean offTrack =
        active
            && duration > 0
            && BigInteger.valueOf(goal.balance())
                    .multiply(BigInteger.valueOf(duration))
                    .compareTo(
                        BigInteger.valueOf(goal.targetAmount())
                            .multiply(BigInteger.valueOf(elapsed)))
                < 0;
    return new Insights(progress, remaining, monthly, offTrack, overdue);
  }
}
