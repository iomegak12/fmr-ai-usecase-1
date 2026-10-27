package com.kalash.goal.common.lifecycle;

import java.util.Arrays;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.context.event.ApplicationReadyEvent;
import org.springframework.boot.info.BuildProperties;
import org.springframework.context.event.ContextClosedEvent;
import org.springframework.context.event.EventListener;
import org.springframework.core.env.Environment;
import org.springframework.stereotype.Component;

@Component
public class ServiceLifecycle {
  private static final Logger LOG = LoggerFactory.getLogger(ServiceLifecycle.class);
  private final Environment environment;
  private final BuildProperties build;

  public ServiceLifecycle(Environment environment, BuildProperties build) {
    this.environment = environment;
    this.build = build;
  }

  @EventListener
  public void ready(ApplicationReadyEvent event) {
    var console = System.console();
    LOG.info(
        summary(
            console != null && console.isTerminal(),
            System.getenv().containsKey("NO_COLOR"),
            event.getTimeTaken().toMillis()));
  }

  String summary(boolean tty, boolean noColor, long durationMs) {
    String port =
        environment.getProperty("local.server.port", environment.getProperty("server.port"));
    String base = "http://localhost:" + safe(port);
    String profiles =
        String.join(
            ",",
            environment.getActiveProfiles().length == 0
                ? environment.getDefaultProfiles()
                : environment.getActiveProfiles());
    String text =
        "startup service=goal-service version="
            + safe(build.getVersion())
            + " profile="
            + safe(profiles)
            + " java="
            + Runtime.version()
            + " port="
            + safe(port)
            + " api="
            + base
            + "/api/v1/goals swagger="
            + base
            + "/swagger-ui openapi="
            + base
            + "/v3/api-docs health="
            + base
            + "/health ready="
            + base
            + "/ready metrics="
            + base
            + "/actuator/prometheus database="
            + safe(environment.getProperty("app.database-host"))
            + ":"
            + safe(environment.getProperty("app.database-port"))
            + "/"
            + safe(environment.getProperty("app.database-name"))
            + " timezone="
            + safe(environment.getProperty("app.timezone"))
            + " logLevel="
            + safe(environment.getProperty("logging.level.root"))
            + " pid="
            + ProcessHandle.current().pid()
            + " startupMs="
            + durationMs;
    boolean docker = Arrays.asList(environment.getActiveProfiles()).contains("docker");
    return tty && !noColor && !docker ? "\u001b[36m" + text + "\u001b[0m" : text;
  }

  private String safe(String value) {
    return value == null ? "unknown" : value.replaceAll("[\\r\\n\\u001b]", "_");
  }

  @EventListener
  public void closed(ContextClosedEvent event) {
    LOG.info(
        "shutdown service=goal-service mode=immediate; Spring closing JPA, Hikari and executors");
  }
}
