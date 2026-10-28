package com.kalash.goal.goal.api;

import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.*;
import java.time.LocalDate;

/** Required create fields for BR-02/04; future-date validation belongs to GoalRules. */
public record CreateGoalRequest(
    @NotBlank @Size(max = 100) @Schema(example = "Goa Trip") String name,
    @NotNull @Positive @Schema(example = "50000", minimum = "1") Long targetAmount,
    @NotNull @Schema(example = "2027-03-31") LocalDate targetDate) {}
