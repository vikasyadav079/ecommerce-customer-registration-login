package org.example.perf.simulations

import io.gatling.core.Predef._
import io.gatling.http.Predef._
import org.example.perf.config.GatlingConfig
import org.example.perf.scenarios.RegistrationScenario

import scala.concurrent.duration._

class RegistrationSimulation extends Simulation {

  // NFR: 1K req/s, p99 < 500ms
  setUp(
    RegistrationScenario.register
      .inject(
        rampUsersPerSec(1).to(1000).during(30.seconds),
        constantUsersPerSec(1000).during(300.seconds)
      )
  ).protocols(GatlingConfig.httpProtocol)
    .assertions(
      global.responseTime.percentile(99).lt(500),
      global.successfulRequests.percent.gt(99.9)
    )
}
