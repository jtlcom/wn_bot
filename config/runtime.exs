import Config

config :whynot_bot, http_port: 9999

# 压测大师配置
config :whynot_bot, SprAdapter,
  url: "http://127.0.0.1:18080",
  is_use: true,
  report_internal: 3000
