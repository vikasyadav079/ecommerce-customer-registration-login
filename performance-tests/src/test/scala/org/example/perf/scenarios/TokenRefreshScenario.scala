package org.example.perf.scenarios

import io.gatling.core.Predef._
import io.gatling.core.structure.ScenarioBuilder
import io.gatling.http.Predef._
import org.example.perf.config.GatlingConfig

object TokenRefreshScenario {

  val refresh: ScenarioBuilder = scenario("Token Refresh Flow")
    .feed(GatlingConfig.testUserFeeder)
    .exec(
      http("Login to get refresh token")
        .post("/api/v1/auth/login")
        .body(StringBody(
          """{
            |  "email": "${email}",
            |  "password": "${password}"
            |}""".stripMargin))
        .check(status.is(200))
        .check(jsonPath("$.data.refreshToken").saveAs("refreshToken"))
    )
    .exec(
      http("POST /api/v1/auth/refresh-token")
        .post("/api/v1/auth/refresh-token")
        .body(StringBody("""{"refreshToken": "${refreshToken}"}"""))
        .check(status.is(200))
        .check(jsonPath("$.data.accessToken").exists)
    )
}
