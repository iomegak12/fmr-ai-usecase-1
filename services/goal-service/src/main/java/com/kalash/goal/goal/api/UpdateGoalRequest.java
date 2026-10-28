package com.kalash.goal.goal.api;

import com.fasterxml.jackson.annotation.JsonIgnore;
import com.fasterxml.jackson.annotation.JsonSetter;
import com.fasterxml.jackson.annotation.Nulls;
import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.*;
import java.time.LocalDate;

/** Partial edit for BR-03/04/05/06; setters distinguish explicit null from absent JSON fields. */
public final class UpdateGoalRequest {
  @Size(min = 1, max = 100)
  @Pattern(regexp = "(?s).*\\S.*")
  @Schema(example = "Goa Trip 2027")
  private String name;

  @Positive
  @Schema(example = "60000")
  private Long targetAmount;

  @Schema(example = "2027-06-30")
  private LocalDate targetDate;

  /** Creates an empty PATCH for Jackson to populate only the supplied fields. */
  public UpdateGoalRequest() {}

  /**
   * @param name optional name
   * @param targetAmount optional target
   * @param targetDate optional date
   */
  @com.fasterxml.jackson.annotation.JsonCreator(
      mode = com.fasterxml.jackson.annotation.JsonCreator.Mode.DISABLED)
  public UpdateGoalRequest(String name, Long targetAmount, LocalDate targetDate) {
    this.name = name;
    this.targetAmount = targetAmount;
    this.targetDate = targetDate;
  }

  /**
   * @param name non-null JSON name
   */
  @JsonSetter(value = "name", nulls = Nulls.FAIL)
  public void setName(String name) {
    this.name = name;
  }

  /**
   * @param amount non-null JSON target
   */
  @JsonSetter(value = "targetAmount", nulls = Nulls.FAIL)
  public void setTargetAmount(Long amount) {
    this.targetAmount = amount;
  }

  /**
   * @param date non-null JSON date
   */
  @JsonSetter(value = "targetDate", nulls = Nulls.FAIL)
  public void setTargetDate(LocalDate date) {
    this.targetDate = date;
  }

  /**
   * @return optional supplied name
   */
  public String name() {
    return name;
  }

  /**
   * @return optional supplied target
   */
  public Long targetAmount() {
    return targetAmount;
  }

  /**
   * @return optional supplied date
   */
  public LocalDate targetDate() {
    return targetDate;
  }

  /**
   * @return whether the PATCH supplies at least one editable field
   */
  @JsonIgnore
  @AssertTrue(message = "At least one field is required")
  public boolean isNonEmpty() {
    return name != null || targetAmount != null || targetDate != null;
  }
}
