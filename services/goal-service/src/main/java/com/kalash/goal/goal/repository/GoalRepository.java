package com.kalash.goal.goal.repository;

import com.kalash.goal.goal.domain.Goal;
import java.util.UUID;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;

/** Derived ORM queries for BR-03 uniqueness and BR-25 overview ordering. */
public interface GoalRepository extends JpaRepository<Goal, UUID> {
  /**
   * @param name trimmed candidate name
   * @return whether an existing goal reserves this case-insensitive name
   */
  boolean existsByNameIgnoreCase(String name);

  /**
   * @param name trimmed candidate name
   * @param goalId the goal being edited
   * @return whether another goal reserves this case-insensitive name
   */
  boolean existsByNameIgnoreCaseAndGoalIdNot(String name, UUID goalId);

  /**
   * @param pageable validated page and size
   * @return goals ordered by target date, creation timestamp, then identity for stable ties
   */
  Page<Goal> findAllByOrderByTargetDateAscCreatedAtAscGoalIdAsc(Pageable pageable);
}
