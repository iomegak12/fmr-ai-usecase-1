package com.kalash.goal.goal.api;

import com.kalash.goal.goal.service.GoalService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import java.net.URI;
import java.util.UUID;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

/** Public LLD Section 13.1 HTTP adapter; delegates all business decisions to GoalService. */
@RestController
@RequestMapping("/api/v1/goals")
@Tag(name = "Goals", description = "Goal lifecycle and savings insights")
public class GoalController {
  private final GoalService service;

  /**
   * @param service goal business operations
   */
  public GoalController(GoalService service) {
    this.service = service;
  }

  /**
   * @param request required goal fields
   * @return 201 with the created representation and Location header
   */
  @PostMapping
  @Operation(summary = "Create an Active savings goal")
  @io.swagger.v3.oas.annotations.responses.ApiResponse(
      responseCode = "201",
      description = "Created Active goal",
      headers =
          @io.swagger.v3.oas.annotations.headers.Header(
              name = "Location",
              description = "Relative URL of the created goal",
              schema = @io.swagger.v3.oas.annotations.media.Schema(type = "string")))
  public ResponseEntity<GoalResponse> create(@Valid @RequestBody CreateGoalRequest request) {
    GoalResponse response = service.create(request);
    return ResponseEntity.created(URI.create("/api/v1/goals/" + response.goalId())).body(response);
  }

  /**
   * @param page zero-based page
   * @param size page size, at most 100
   * @return all statuses sorted by target date and creation time
   */
  @GetMapping
  @Operation(summary = "List goals with read-time insights")
  public PageResponse<GoalResponse> list(
      @RequestParam(defaultValue = "0") @Min(0) int page,
      @RequestParam(defaultValue = "20") @Min(1) @Max(100) int size) {
    return service.list(page, size);
  }

  /**
   * @param goalId goal identity
   * @return goal details, including read-time insights
   */
  @GetMapping("/{goalId}")
  @Operation(summary = "Read a goal and its savings insights")
  public GoalResponse get(@PathVariable UUID goalId) {
    return service.get(goalId);
  }

  /**
   * @param goalId goal identity
   * @param request supplied edit fields
   * @return the updated goal
   */
  @PatchMapping("/{goalId}")
  @Operation(summary = "Edit permitted goal fields")
  public GoalResponse update(
      @PathVariable UUID goalId, @Valid @RequestBody UpdateGoalRequest request) {
    return service.update(goalId, request);
  }

  /**
   * @param goalId goal identity
   * @return a Cancelled goal with null insights
   */
  @PostMapping("/{goalId}/cancel")
  @Operation(summary = "Cancel an Active goal with zero balance")
  public GoalResponse cancel(@PathVariable UUID goalId) {
    return service.cancel(goalId);
  }
}
