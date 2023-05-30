# This file is responsible for configuring your umbrella
# and **all applications** and their dependencies with the
# help of the Config module.
#
# Note that all applications in your umbrella share the
# same configuration and dependencies, which is why they
# all use the same configuration file. If you want different
# configurations or dependencies per app, it is best to
# move said applications out of the umbrella.
import Config

config :whynot_bot, port: 8700
config :whynot_bot, http_port: 9999

config :whynot_bot, recv_buff: 10

config :whynot_bot,
  wetest_api: %{
    apiurl: "http://api.wetest.qq.com",
    secretid: "W0NRWmZBY1dC3rSm",
    secretkey: "PPif6drSzHqsVWS4",
    projectid: "b30a017fb2cb54ce762fc54ab83cd903",
    zoneid: 0
  }

config :logger, handle_otp_reports: true, handle_sasl_reports: true
config :logger, backends: [:console, {LoggerFileBackend, :log_file}]

config :logger, :console,
  format: "<=====$time $metadata[$level] ======>\n\n $message\n\n",
  metadata: [:module, :function, :line],
  level: :debug

config :logger, :log_file,
  path: "./info.log",
  rotate: %{max_bytes: 104_857_600, keep: 1},
  format: "\n$date $time $metadata[$level] $message\n"
