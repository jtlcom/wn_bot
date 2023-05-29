# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
use Mix.Config

# This configuration is loaded before any dependency and is restricted
# to this project. If another project depends on this project, this
# file won't be loaded nor affect the parent project. For this reason,
# if you want to provide default values for your application for
# 3rd-party users, it should be done in your "mix.exs" file.

# You can configure your application as:
#
#     config :pressure_test, key: :value
#
# and access this configuration in your application as:
#
#     Application.get_env(:pressure_test, :key)
#
# You can also configure a 3rd-party app:
#
#     config :logger, level: :info
#
# config :pressure_test, ip: 'stress.my3d.qq.com'
# config :pressure_test, port: 9003

# config :pressure_test, ip: 'realm.my3d.qq.com'
# config :pressure_test, port: 25005

config :pressure_test, ip: '192.168.1.184'
config :pressure_test, port: 8700
config :pressure_test, http_port: 9999

config :pressure_test, recv_buff: 10

config :pressure_test,
  wetest_api: %{
    apiurl: "http://api.wetest.qq.com",
    secretid: "W0NRWmZBY1dC3rSm",
    secretkey: "PPif6drSzHqsVWS4",
    projectid: "b30a017fb2cb54ce762fc54ab83cd903",
    zoneid: 0
  }

config :pressure_test, Scheduler,
  timezone: "Asia/Shanghai",
  jobs: []

config :tzdata, :autoupdate, :disabled

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
