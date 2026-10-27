package com.kalash.goal.common.error;

import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.ConstraintViolationException;
import java.net.URI;
import java.time.Clock;
import java.util.List;
import java.util.Map;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.slf4j.MDC;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.dao.OptimisticLockingFailureException;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatusCode;
import org.springframework.http.ProblemDetail;
import org.springframework.http.ResponseEntity;
import org.springframework.web.ErrorResponse;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.context.request.ServletWebRequest;
import org.springframework.web.context.request.WebRequest;
import org.springframework.web.servlet.mvc.method.annotation.ResponseEntityExceptionHandler;

/** RFC 9457 boundary; driver messages, stack traces and rejected values stay out of responses. */
@RestControllerAdvice
public class GlobalExceptionHandler extends ResponseEntityExceptionHandler {
  private static final Logger LOG = LoggerFactory.getLogger(GlobalExceptionHandler.class);
  private final Clock clock;

  /**
   * @param clock injected application clock, fixed in tests
   */
  public GlobalExceptionHandler(Clock clock) {
    this.clock = clock;
  }

  /**
   * Converts application and persistence failures to the public contract.
   *
   * @param exception failure to translate
   * @param request incoming request
   * @return a sanitized problem response
   */
  @ExceptionHandler({
    ApiException.class,
    DataIntegrityViolationException.class,
    OptimisticLockingFailureException.class,
    ConstraintViolationException.class,
    Exception.class
  })
  public ProblemDetail handleFailure(Exception exception, HttpServletRequest request) {
    ErrorCode code =
        switch (exception) {
          case ApiException api -> api.errorCode();
          case DataIntegrityViolationException integrity -> ConstraintErrorMapper.map(integrity);
          case OptimisticLockingFailureException ignored -> ErrorCode.COMMON_409;
          case ConstraintViolationException ignored -> ErrorCode.COMMON_400;
          default -> ErrorCode.COMMON_500;
        };
    if (exception instanceof ErrorResponse response) {
      int status = response.getStatusCode().value();
      return problem(frameworkCode(status), status, request);
    }
    return problem(code, code.status(), request);
  }

  @Override
  protected ResponseEntity<Object> handleExceptionInternal(
      Exception exception,
      Object body,
      HttpHeaders headers,
      HttpStatusCode status,
      WebRequest request) {
    ErrorCode code = frameworkCode(status.value());
    ProblemDetail problem =
        problem(code, status.value(), ((ServletWebRequest) request).getRequest());
    if (exception instanceof MethodArgumentNotValidException validation) {
      problem.setProperty(
          "errors",
          validation.getBindingResult().getFieldErrors().stream()
              .map(error -> Map.of("field", error.getField(), "message", "Invalid value"))
              .toList());
    }
    return super.handleExceptionInternal(exception, problem, headers, status, request);
  }

  private ErrorCode frameworkCode(int status) {
    return status == 400 ? ErrorCode.COMMON_400 : status >= 500 ? ErrorCode.COMMON_500 : null;
  }

  private ProblemDetail problem(ErrorCode code, int status, HttpServletRequest request) {
    String title = code == null ? "Request rejected" : code.title();
    ProblemDetail problem = ProblemDetail.forStatusAndDetail(HttpStatusCode.valueOf(status), title);
    problem.setTitle(title);
    if (code != null) {
      problem.setType(URI.create("urn:kalash:error:" + code.code()));
      problem.setProperty("errorCode", code.code());
    }
    problem.setInstance(URI.create(request.getRequestURI()));
    problem.setProperty("correlationId", MDC.get("correlationId"));
    problem.setProperty("timestamp", clock.instant().toString());
    if (code == ErrorCode.COMMON_400) {
      problem.setProperty(
          "errors", List.of(Map.of("field", "request", "message", "Invalid value")));
    }
    if (status >= 500) {
      LOG.error(
          "request_rejected errorCode={} status={}", code == null ? "none" : code.code(), status);
    } else {
      LOG.warn(
          "request_rejected errorCode={} status={}", code == null ? "none" : code.code(), status);
    }
    return problem;
  }
}
