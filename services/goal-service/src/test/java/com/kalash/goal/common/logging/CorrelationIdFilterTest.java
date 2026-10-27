package com.kalash.goal.common.logging;

import static org.assertj.core.api.Assertions.*;

import jakarta.servlet.DispatcherType;
import jakarta.servlet.ServletException;
import java.util.UUID;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.NullAndEmptySource;
import org.junit.jupiter.params.provider.ValueSource;
import org.slf4j.MDC;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.mock.web.MockHttpServletResponse;

class CorrelationIdFilterTest {
  private final CorrelationIdFilter filter = new CorrelationIdFilter();

  @AfterEach
  void clearMdc() {
    MDC.clear();
  }

  @ParameterizedTest
  @NullAndEmptySource
  @ValueSource(
      strings = {
        "bad\r\nheader",
        "a b",
        "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
      })
  void replacesMissingOrUnsafeHeaders(String supplied) throws Exception {
    var request = new MockHttpServletRequest();
    var response = new MockHttpServletResponse();
    if (supplied != null) {
      request.addHeader(CorrelationIdFilter.HEADER, supplied);
    }
    filter.doFilter(
        request,
        response,
        (req, res) ->
            assertThat(MDC.get("correlationId"))
                .isEqualTo(response.getHeader(CorrelationIdFilter.HEADER)));
    assertThatCode(() -> UUID.fromString(response.getHeader(CorrelationIdFilter.HEADER)))
        .doesNotThrowAnyException();
    assertThat(MDC.get("correlationId")).isNull();
  }

  @Test
  void echoesBeforeFailuresAndRestoresExistingMdc() {
    var request = new MockHttpServletRequest();
    request.addHeader(CorrelationIdFilter.HEADER, "upstream-1");
    var response = new MockHttpServletResponse();
    MDC.put("correlationId", "outer");
    assertThatThrownBy(
            () ->
                filter.doFilter(
                    request,
                    response,
                    (req, res) -> {
                      assertThat(MDC.get("correlationId")).isEqualTo("upstream-1");
                      throw new ServletException("failure");
                    }))
        .isInstanceOf(ServletException.class);
    assertThat(response.getHeader(CorrelationIdFilter.HEADER)).isEqualTo("upstream-1");
    assertThat(MDC.get("correlationId")).isEqualTo("outer");
  }

  @Test
  void redispatchRetainsGeneratedCorrelation() throws Exception {
    var request = new MockHttpServletRequest();
    var response = new MockHttpServletResponse();
    filter.doFilter(request, response, (req, res) -> {});
    String original = response.getHeader(CorrelationIdFilter.HEADER);
    request.setDispatcherType(DispatcherType.ERROR);
    request.setAttribute("jakarta.servlet.error.request_uri", "/failed");
    response = new MockHttpServletResponse();
    filter.doFilter(
        request, response, (req, res) -> assertThat(MDC.get("correlationId")).isEqualTo(original));
    assertThat(response.getHeader(CorrelationIdFilter.HEADER)).isEqualTo(original);
    assertThat(filter.shouldNotFilterAsyncDispatch()).isFalse();
    assertThat(filter.shouldNotFilterErrorDispatch()).isFalse();
  }
}
