package com.kalash.goal;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

@SpringBootApplication
public class GoalServiceApplication {
  public static void main(String[] args) {
    if (System.getenv().containsKey("NO_COLOR")) {
      System.setProperty("spring.output.ansi.enabled", "never");
    }
    SpringApplication.run(GoalServiceApplication.class, args);
  }
}
