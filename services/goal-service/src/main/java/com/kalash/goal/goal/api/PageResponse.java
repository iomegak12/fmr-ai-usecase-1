package com.kalash.goal.goal.api;

import java.util.List;
import org.springframework.data.domain.Page;

/** Stable zero-based pagination envelope specified in LLD Section 12. */
public record PageResponse<T>(
    List<T> content, int page, int size, long totalElements, int totalPages) {
  /**
   * @param result the ORM page mapped to response objects
   * @return the public envelope without Spring-specific pagination internals
   */
  public static <T> PageResponse<T> from(Page<T> result) {
    return new PageResponse<>(
        result.getContent(),
        result.getNumber(),
        result.getSize(),
        result.getTotalElements(),
        result.getTotalPages());
  }
}
