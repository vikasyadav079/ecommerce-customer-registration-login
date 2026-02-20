package org.example.perf.simulations

import io.gatling.core.Predef._
import io.gatling.http.Predef._
import org.example.perf.config.GatlingConfig
import org.example.perf.scenarios.TokenRefreshScenario

import scala.concurrent.duration._

class TokenRefreshSimulation extends Simulation {

  // NFR: 5K req/s, p99 < 50ms
  setUp(
    TokenRefreshScenario.refresh
      .inject(
        rampUsersPerSec(1).to(5000).during(30.seconds),
        constantUsersPerSec(5000).during(300.seconds)
      )
  ).protocols(GatlingConfig.httpProtocol)
    .assertions(
      global.responseTime.percentile(99).lt(50),
      global.successfulRequests.percent.gt(99.9)
    )
}
