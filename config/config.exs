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

config :whynot_bot, http_port: 9999

config :whynot_bot, recv_buff: 10
config :hackney, max_connections: 1000

config :whynot_bot, SprAdapter,
  url: "http://192.168.1.129:18080",
  is_use: true,
  report_internal: 3000

config :whynot_bot, is_write_avatar: true

config :tzdata, autoupdate: :disabled
config :timex, local_timezone: "Asia/Shanghai"
config :logger, handle_otp_reports: true, handle_sasl_reports: true
config :logger, backends: [:console, {LoggerFileBackend, :log_file}]

config :logger, :console,
  format: "<=====$time $metadata[$level] ======>\n\n $message\n\n",
  metadata: [:module, :function, :line],
  level: :debug

config :logger, :log_file,
  path: "./logger/info.log",
  rotate: %{max_bytes: 104_857_600, keep: 10},
  format: "\n$date $time $metadata[$level] $message\n",
  level: :debug
