package org.example.perf.scenarios

import io.gatling.core.Predef._
import io.gatling.core.structure.ScenarioBuilder
import io.gatling.http.Predef._
import org.example.perf.config.GatlingConfig

object LoginScenario {

  val login: ScenarioBuilder = scenario("Login Flow")
    .feed(GatlingConfig.testUserFeeder)
    .exec(
      http("POST /api/v1/auth/login")
        .post("/api/v1/auth/login")
        .body(StringBody(
          """{
            |  "email": "${email}",
            |  "password": "${password}"
            |}""".stripMargin))
        .check(status.is(200))
        .check(jsonPath("$.data.accessToken").saveAs("accessToken"))
    )
    .exec(
      http("GET /api/v1/auth/me (validate JWT)")
        .get("/api/v1/auth/me")
        .header("Authorization", "Bearer ${accessToken}")
        .check(status.is(200))
    )
}
