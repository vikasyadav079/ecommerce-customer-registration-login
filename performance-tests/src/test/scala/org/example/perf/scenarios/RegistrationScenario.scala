package org.example.perf.scenarios

import io.gatling.core.Predef._
import io.gatling.core.structure.ScenarioBuilder
import io.gatling.http.Predef._

object RegistrationScenario {

  val register: ScenarioBuilder = scenario("Registration Flow")
    .exec(session => session.set("uniqueId", java.util.UUID.randomUUID().toString.take(8)))
    .exec(
      http("POST /api/v1/auth/register")
        .post("/api/v1/auth/register")
        .body(StringBody(
          """{
            |  "email": "perf-${uniqueId}@test.ecommerce.com",
            |  "password": "Test@12345678",
            |  "firstName": "Perf",
            |  "lastName": "User"
            |}""".stripMargin))
        .check(status.is(201))
    )
}
