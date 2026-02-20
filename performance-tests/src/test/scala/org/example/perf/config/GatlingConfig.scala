package org.example.perf.config

import io.gatling.core.Predef._
import io.gatling.http.Predef._
import io.gatling.http.protocol.HttpProtocolBuilder

object GatlingConfig {

  val baseUrl: String = System.getProperty("base.url", "http://localhost:8080")

  val httpProtocol: HttpProtocolBuilder = http
    .baseUrl(baseUrl)
    .acceptHeader("application/json")
    .contentTypeHeader("application/json")
    .userAgentHeader("Gatling Performance Test")
    .header("X-Request-ID", session => java.util.UUID.randomUUID().toString)

  val testUserFeeder = csv("data/test-users.csv").random
}
