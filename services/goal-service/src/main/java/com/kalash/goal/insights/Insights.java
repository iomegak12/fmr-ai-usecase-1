package com.kalash.goal.insights;

import java.math.BigDecimal;

/** Derived savings guidance implementing BR-21 through BR-24; never stored in the database. */
public record Insights(
    BigDecimal progressPercent,
    long remainingAmount,
    long suggestedMonthlySaving,
    boolean offTrack,
    boolean overdue) {}
