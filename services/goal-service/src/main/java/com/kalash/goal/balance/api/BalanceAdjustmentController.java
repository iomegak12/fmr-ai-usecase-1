package com.kalash.goal.balance.api;

import com.kalash.goal.balance.service.BalanceAdjustmentService;
import com.kalash.goal.goal.service.GoalService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;

/** LLD Section 14 internal adapter; the future gateway must not expose these routes. */
@RestController
@RequestMapping("/internal/v1/goals")
@Tag(name = "Internal")
public class BalanceAdjustmentController {
  private final GoalService goals;
  private final BalanceAdjustmentService balances;

  /**
   * @param goals goal operations
   * @param balances balance business operations
   */
  public BalanceAdjustmentController(GoalService goals, BalanceAdjustmentService balances) {
    this.goals = goals;
    this.balances = balances;
  }

  /**
   * @param goalId goal identity
   * @return current internal state
   */
  @GetMapping("/{goalId}")
  @Operation(summary = "Read the goal status and balance")
  public GoalSnapshot get(@PathVariable UUID goalId) {
    return GoalSnapshot.from(goals.require(goalId));
  }

  /**
   * @param goalId goal identity
   * @param request operation and signed delta
   * @return committed internal state
   */
  @PostMapping("/{goalId}/balance-adjustments")
  @Operation(summary = "Validate and apply a balance adjustment")
  public GoalSnapshot adjust(
      @PathVariable UUID goalId, @Valid @RequestBody BalanceAdjustmentRequest request) {
    return balances.adjust(goalId, request);
  }

  /**
   * @param goalId identity of a Cancelled goal
   */
  @DeleteMapping("/{goalId}")
  @ResponseStatus(HttpStatus.NO_CONTENT)
  @Operation(summary = "Delete a Cancelled goal after history cleanup")
  public void delete(@PathVariable UUID goalId) {
    goals.deleteCancelled(goalId);
  }
}
