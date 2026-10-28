package com.kalash.goal.common.config;

import com.kalash.goal.common.error.ErrorCode;
import io.swagger.v3.oas.models.Operation;
import io.swagger.v3.oas.models.PathItem.HttpMethod;
import io.swagger.v3.oas.models.examples.Example;
import io.swagger.v3.oas.models.media.*;
import io.swagger.v3.oas.models.responses.ApiResponse;
import java.util.*;
import org.springdoc.core.customizers.OpenApiCustomizer;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

/** Documents concrete request, success and RFC 9457 examples for the implemented Goal contracts. */
@Configuration(proxyBeanMethods = false)
public class GoalApiDocumentation {
  private static final String ID = "10000000-0000-0000-0000-000000000001";

  @Bean
  OpenApiCustomizer goalProblemExamples() {
    return api ->
        api.getPaths()
            .forEach(
                (path, item) -> {
                  if (!path.startsWith("/api/v1/goals") && !path.startsWith("/internal/v1/goals"))
                    return;
                  item.readOperationsMap()
                      .forEach(
                          (method, operation) -> {
                            addSuccessExamples(path, operation);
                            for (ErrorCode code : codes(path, method))
                              addProblem(path, operation, code);
                          });
                });
  }

  private List<ErrorCode> codes(String path, HttpMethod method) {
    List<ErrorCode> codes = new ArrayList<>(List.of(ErrorCode.COMMON_400, ErrorCode.COMMON_500));
    if (path.contains("{goalId}")) codes.add(ErrorCode.GOAL_001);
    if (method != HttpMethod.GET) codes.add(ErrorCode.COMMON_409);
    if (path.endsWith("balance-adjustments")) {
      codes.addAll(
          List.of(ErrorCode.GOAL_009, ErrorCode.GOAL_010, ErrorCode.GOAL_011, ErrorCode.GOAL_012));
    } else if (path.endsWith("/cancel")) {
      codes.addAll(List.of(ErrorCode.GOAL_006, ErrorCode.GOAL_007));
    } else if (method == HttpMethod.DELETE) {
      codes.add(ErrorCode.GOAL_008);
    } else if (method == HttpMethod.PATCH) {
      codes.addAll(
          List.of(ErrorCode.GOAL_002, ErrorCode.GOAL_003, ErrorCode.GOAL_004, ErrorCode.GOAL_005));
    } else if (method == HttpMethod.POST) {
      codes.addAll(List.of(ErrorCode.GOAL_002, ErrorCode.GOAL_003));
    }
    return codes;
  }

  private void addProblem(String path, Operation operation, ErrorCode code) {
    ApiResponse response =
        operation
            .getResponses()
            .computeIfAbsent(
                Integer.toString(code.status()),
                ignored ->
                    new ApiResponse()
                        .description("Goal API rejection; see errorCode examples")
                        .content(
                            new Content()
                                .addMediaType(
                                    "application/problem+json",
                                    new MediaType()
                                        .schema(
                                            new ObjectSchema()
                                                .addProperty("type", new StringSchema())
                                                .addProperty("title", new StringSchema())
                                                .addProperty("status", new IntegerSchema())
                                                .addProperty("detail", new StringSchema())
                                                .addProperty("instance", new StringSchema())
                                                .addProperty("errorCode", new StringSchema())
                                                .addProperty("correlationId", new StringSchema())
                                                .addProperty("timestamp", new DateTimeSchema())
                                                .addProperty(
                                                    "errors",
                                                    new ArraySchema()
                                                        .items(
                                                            new ObjectSchema()
                                                                .addProperty(
                                                                    "field", new StringSchema())
                                                                .addProperty(
                                                                    "message",
                                                                    new StringSchema())))))));
    Map<String, Object> example = new LinkedHashMap<>();
    example.put("type", "urn:kalash:error:" + code.code());
    example.put("title", code.title());
    example.put("status", code.status());
    example.put("detail", code.title());
    example.put("instance", path.replace("{goalId}", ID));
    example.put("errorCode", code.code());
    example.put("correlationId", "example-correlation-id");
    example.put("timestamp", "2026-10-27T06:30:00Z");
    if (code == ErrorCode.COMMON_400)
      example.put("errors", List.of(Map.of("field", "request", "message", "Invalid value")));
    response
        .getContent()
        .get("application/problem+json")
        .addExamples(code.code(), new Example().value(example));
  }

  private void addSuccessExamples(String path, Operation operation) {
    Map<String, Object> goal =
        new LinkedHashMap<>(
            Map.of(
                "goalId",
                ID,
                "name",
                "Goa Trip",
                "targetAmount",
                50000,
                "targetDate",
                "2027-03-31",
                "balance",
                0,
                "status",
                "ACTIVE",
                "createdAt",
                "2026-10-27T06:30:00Z",
                "updatedAt",
                "2026-10-27T06:30:00Z"));
    goal.put(
        "insights",
        Map.of(
            "progressPercent",
            0.0,
            "remainingAmount",
            50000,
            "suggestedMonthlySaving",
            10000,
            "offTrack",
            false,
            "overdue",
            false));
    if (path.endsWith("/cancel")) {
      goal.put("status", "CANCELLED");
      goal.put("insights", null);
    }
    Object success =
        path.startsWith("/internal/")
            ? Map.of("goalId", ID, "status", "ACTIVE", "balance", 5000, "targetAmount", 50000)
            : goal;
    if (operation.getRequestBody() != null) {
      Object request =
          path.startsWith("/internal/")
              ? Map.of("operation", "DEPOSIT", "delta", 5000)
              : Map.of("name", "Goa Trip", "targetAmount", 50000, "targetDate", "2027-03-31");
      operation.getRequestBody().getContent().values().forEach(media -> media.setExample(request));
    } else if (path.equals("/api/v1/goals")) {
      success =
          Map.of(
              "content", List.of(goal), "page", 0, "size", 20, "totalElements", 1, "totalPages", 1);
    }
    Object example = success;
    operation
        .getResponses()
        .forEach(
            (status, response) -> {
              if (status.startsWith("2") && response.getContent() != null)
                response.getContent().values().forEach(media -> media.setExample(example));
            });
  }
}
