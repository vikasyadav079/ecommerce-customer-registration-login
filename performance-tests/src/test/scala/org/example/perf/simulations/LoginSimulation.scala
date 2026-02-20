package org.example.perf.simulations

import io.gatling.core.Predef._
import io.gatling.http.Predef._
import org.example.perf.config.GatlingConfig
import org.example.perf.scenarios.LoginScenario

import scala.concurrent.duration._

class LoginSimulation extends Simulation {

  // NFR: 10K req/s sustained, p99 < 200ms, error rate < 0.1%
  setUp(
    LoginScenario.login
      .inject(
        rampUsersPerSec(1).to(10000).during(60.seconds),
        constantUsersPerSec(10000).during(300.seconds)
      )
  ).protocols(GatlingConfig.httpProtocol)
    .assertions(
      global.responseTime.percentile(99).lt(200),
      global.successfulRequests.percent.gt(99.9)
    )
}
