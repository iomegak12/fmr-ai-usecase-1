package com.kalash.goal.goal.domain;

import jakarta.persistence.*;
import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.time.temporal.ChronoUnit;
import java.util.UUID;

/** Goal persistence model; implements optimistic locking and whole-rupee storage (BR-04/14). */
@Entity
@Table(name = "goals")
public class Goal {
  @Id
  @Column(name = "goal_id")
  private UUID goalId;

  @Column(nullable = false, length = 100)
  private String name;

  @Column(name = "target_amount", nullable = false)
  private long targetAmount;

  @Column(name = "target_date", nullable = false)
  private LocalDate targetDate;

  @Column(nullable = false)
  private long balance;

  @Enumerated(EnumType.STRING)
  @Column(nullable = false, length = 10)
  private GoalStatus status;

  @Version private Long version;

  @Column(name = "created_at", nullable = false, updatable = false)
  private OffsetDateTime createdAt;

  @Column(name = "updated_at", nullable = false)
  private OffsetDateTime updatedAt;

  protected Goal() {}

  /**
   * Creates an Active, zero-balance goal (BR-01/02).
   *
   * @param name normalized unique name
   * @param targetAmount validated positive amount
   * @param targetDate validated future date
   * @param now UTC creation timestamp from the injected clock
   */
  public Goal(String name, long targetAmount, LocalDate targetDate, OffsetDateTime now) {
    this.goalId = UUID.randomUUID();
    this.name = name;
    this.targetAmount = targetAmount;
    this.targetDate = targetDate;
    this.status = GoalStatus.ACTIVE;
    this.createdAt = now.truncatedTo(ChronoUnit.MICROS);
    this.updatedAt = this.createdAt;
  }

  /**
   * @return the immutable goal identity
   */
  public UUID goalId() {
    return goalId;
  }

  /**
   * @return the trimmed display name
   */
  public String name() {
    return name;
  }

  /**
   * @return the whole-rupee savings target
   */
  public long targetAmount() {
    return targetAmount;
  }

  /**
   * @return the business target date
   */
  public LocalDate targetDate() {
    return targetDate;
  }

  /**
   * @return the whole-rupee balance
   */
  public long balance() {
    return balance;
  }

  /**
   * @return the current lifecycle state
   */
  public GoalStatus status() {
    return status;
  }

  /**
   * @return the original UTC creation timestamp
   */
  public OffsetDateTime createdAt() {
    return createdAt;
  }

  /**
   * @return the latest UTC modification timestamp
   */
  public OffsetDateTime updatedAt() {
    return updatedAt;
  }

  /**
   * Applies validated edits; preserves the creation date (BR-03/05/06).
   *
   * @param name optional replacement name
   * @param amount optional replacement target
   * @param date optional replacement date
   */
  public void edit(String name, Long amount, LocalDate date) {
    if (name != null) this.name = name;
    if (amount != null) this.targetAmount = amount;
    if (date != null) this.targetDate = date;
  }

  /**
   * @param balance validated resulting balance (BR-14)
   */
  public void changeBalance(long balance) {
    this.balance = balance;
  }

  /**
   * @param status evaluated lifecycle state (BR-15/16/18)
   */
  public void changeStatus(GoalStatus status) {
    this.status = status;
  }

  /**
   * @param now modification instant from the injected clock
   */
  public void touch(OffsetDateTime now) {
    this.updatedAt = now.truncatedTo(ChronoUnit.MICROS);
  }
}
