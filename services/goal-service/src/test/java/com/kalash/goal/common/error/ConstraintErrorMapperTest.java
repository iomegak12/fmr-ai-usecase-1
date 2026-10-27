package com.kalash.goal.common.error;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import java.sql.SQLException;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.CsvSource;
import org.postgresql.util.PSQLException;
import org.postgresql.util.PSQLState;
import org.postgresql.util.ServerErrorMessage;
import org.springframework.dao.DataIntegrityViolationException;

class ConstraintErrorMapperTest {
  @ParameterizedTest
  @CsvSource({
    "ux_goals_name_ci, GOAL_002",
    "goals_balance_check, GOAL_012",
    "goals_target_amount_check, COMMON_400",
    "goals_status_check, COMMON_400",
    "unknown_check, COMMON_500"
  })
  void mapsStructuredHibernateConstraintNames(String constraint, ErrorCode expected) {
    var hibernate =
        new org.hibernate.exception.ConstraintViolationException(
            "private SQL", new SQLException(), constraint);
    assertThat(ConstraintErrorMapper.map(new DataIntegrityViolationException("private", hibernate)))
        .isEqualTo(expected);
  }

  @ParameterizedTest
  @CsvSource({
    "23505,goals,name,ux_goals_name_ci,GOAL_002",
    "23514,goals,balance,goals_balance_check,GOAL_012",
    "23502,goals,name,,COMMON_400",
    "23502,goals,target_amount,,COMMON_400",
    "23502,goals,target_date,,COMMON_400",
    "23502,goals,balance,,COMMON_400",
    "23502,goals,status,,COMMON_400",
    "23502,goals,id,,COMMON_500",
    "23502,other,name,,COMMON_500",
    "23502,goals,,,COMMON_500",
    "99999,goals,name,,COMMON_500"
  })
  void mapsPostgresMetadataWithoutParsingMessages(
      String state, String table, String column, String constraint, ErrorCode expected) {
    var metadata = mock(ServerErrorMessage.class);
    when(metadata.getSQLState()).thenReturn(state);
    when(metadata.getTable()).thenReturn(table);
    when(metadata.getColumn()).thenReturn(column);
    when(metadata.getConstraint()).thenReturn(constraint);
    assertThat(ConstraintErrorMapper.map(new PSQLException(metadata))).isEqualTo(expected);
  }

  @Test
  void unknownAndNullMetadataRemainInternalErrorsAndCauseCyclesTerminate() {
    assertThat(ConstraintErrorMapper.map(null)).isEqualTo(ErrorCode.COMMON_500);
    assertThat(
            ConstraintErrorMapper.map(
                new PSQLException("ux_goals_name_ci private", PSQLState.UNKNOWN_STATE)))
        .isEqualTo(ErrorCode.COMMON_500);
    assertThat(
            ConstraintErrorMapper.map(
                new org.hibernate.exception.ConstraintViolationException(
                    "private", new SQLException(), null)))
        .isEqualTo(ErrorCode.COMMON_500);
    var cycle = mock(Throwable.class);
    when(cycle.getCause()).thenReturn(cycle);
    assertThat(ConstraintErrorMapper.map(cycle)).isEqualTo(ErrorCode.COMMON_500);
  }
}
