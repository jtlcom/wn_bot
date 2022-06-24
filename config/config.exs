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

config :pressure_test, config_base_url: "http://192.168.1.238:5984/develop/"
config :pressure_test, load_config: false

config :pressure_test, log_to_file: false
config :pressure_test, start_id: 1

# 进入人数
config :pressure_test, start_num: 1
# 聊天机器人数量
config :pressure_test, chat_broadcast_num: 0
# 进入间隔
config :pressure_test, enter_delay: 100
config :pressure_test, addition: 5
config :pressure_test, leave_after: 120    # min
config :pressure_test, strategy: 'once_time'

# 世界消息发送延时 ，s
config :pressure_test, broadcast_delay: 20
config :pressure_test, default_stat: 0
config :pressure_test, robot_gene: [11, 22, 32]
# config :pressure_test, eudemonds: %{
#   1 => [
#     203010201,
#     203010202,
#     203010203,
#     203010204,
#     203010301,
#     203010302,
#     203010303,
#     203010304,
#     203010305,
#     203010306,
#     203010307,
#     203010401,
#     203010402,
#     203010403,
#     203010404,
#     203010405,
#     203010406,
#     203010502
#   ],
#   2 => [
#     203010503,
#     203010504,
#     203010506,
#     203010510,
#     203010507,
#     203010505,
#     203010508,
#     203010509,
#     203010601,
#     203010602,
#     203040204,
#     203020101,
#     203030201,
#     203030202,
#     203030203,
#     203030204,
#     203030301,
#     203030302,
#     203030303,
#     203030304,
#     203030305
#   ],
#   3 => [
#     203030306,
#     203030307,
#     203030401,
#     203030402,
#     203030403,
#     203030404,
#     203030405,
#     203030406,
#     203030502,
#     203030503,
#     203030504,
#     203030506,
#     203030510,
#     203030507,
#     203030505,
#     203030508,
#     203030509,
#     203030601,
#     203030602
#   ]
# }

config :pressure_test, msg_broadcast: ["*+*", "(*><*)", "^_^", "^@^", "->_->"]

# config :pressure_test, line_avatar: 100
# It is also possible to import configuration files, relative to this
# directory. For example, you can emulate configuration per environment
# by uncommenting the line below and defining dev.exs, test.exs and such.
# Configuration from the imported file will override the ones defined
# here (which is why it is important to import them last).
#
#     import_config "#{Mix.env}.exs"
config :tzdata, :autoupdate, :disabled

config :pressure_test, wetest_api: %{
  apiurl: "http://api.wetest.qq.com",
  secretid: "W0NRWmZBY1dC3rSm",
  secretkey: "PPif6drSzHqsVWS4",
  projectid: "b30a017fb2cb54ce762fc54ab83cd903",
  zoneid: 0
}
config :pressure_test, Scheduler,
  timezone: "Asia/Shanghai",
  jobs: []

config :logger, :console, format: "<=====$time $metadata[$level] ======>\n\n $levelpad$message\n\n",
  metadata: [:module, :function, :line], level: :warn

config :pressure_test, mnesia_init_table: [Mnesiam.AvatarLines]
config :pressure_test, recv_buff: 10
config :pressure_test, chat_recv_buff: 1
config :pressure_test, response_reply_url: "http://openapi.tuling123.com/openapi/api/v2"
config :pressure_test, api_key: "3656ccc3481640f2b56ee517c50ae3ee"
config :pressure_test, user_id: "longlong"

config :logger, backends: [{LoggerFileBackend, :info}] # {LoggerFileBackend, :debug},
# config :logger, :debug, path: "lib/log/debug.log", level: :debug
config :logger, :info, path: "./info.log", level: :info, rotate: %{max_bytes: 10485760, keep: 5}, format: "\n$date $time $metadata[$level] $levelpad$message\n"

config :pressure_test, need_group: false
config :pressure_test, create_group_num: 120
config :pressure_test, level_range: 260..300

config :pressure_test, preconditions: [
  # ["gm:open_act", 116, 600]
  # ["gm:random_act_auction", 118, 200],
  # ["gm:open_act", 125, 6000]
  # ["gm:open_act", 118, 600],
  # ["gm:open_act", 116, 600],
  # ["gm:open_act", 117, 600]
  ]
config :pressure_test, auto_reply: [
    # {:reply, ["shop:list", 101]}, 10000
    # {:reply, ["gm:add_eudemon", 203010201, 50, 20]}, 10000,
    # {:reply, ["gm:add_eudemon", 203010201, 50, 20]}, 12000,
    # {:reply, ["gm:add_eudemon", 203010201, 50, 20]}, 14000,
    # {:reply, ["battle_field:player_enter"]}, 20000
    # {:reply, ["gm:add_eudemon", 203010201, 50, 20]}, 10000,
    # {:reply, ["gm:add_eudemon", 203010201, 50, 20]}, 12000,
    # {:reply, ["gm:add_eudemon", 203010201, 50, 20]}, 14000
    # {:reply, ["change_scene", 1, 102111]}, 20000
    # {:reply, ["shop:list", 101]}, 10000,
    # {:reply, ["shop:list", 102]}, 10000,
    # :trade_all, 20000
    # {:reply, ["change_scene", 1, 411001]}, 20000
    # {:reply, ["territory_warfare:player_enter"]}, 180000
    # {:reply, ["change_scene", 203011]}, 20000
    {:reply, ["gm:add_eudemon", 203010406, 110, 110]}, 10000,
    # {:reply, ["gm:add_eudemon", 203010602, 150, 150]}, 12000,
    # {:reply, ["gm:add_eudemon", 203010505, 50, 50]}, 14000,
    # # {:reply, ["battle_field:player_enter"]}, 20000,
    # {:reply, ["shop:list", 101]}, 10000,
    # {:reply, ["shop:list", 102]}, 10000,
    # :trade_all, 20000
  ]

config :pressure_test, by_strategy: false
config :pressure_test, strategy_reply: [
    # {:reply, ["battle_field:player_enter"]}, 20000,
    # {:reply, ["battle_field:player_enter"]}, 180000,
    # {:reply, ["battle_field:player_enter"]}, 300000,
    # {:reply, ["battle_field:player_enter"]}, 10000,
    # {:reply, ["short_treasure:player_enter"]}, 10000,
    # :trade_all, 20000,
    # {:reply, ["shop:list", 101]}, 10000,
    # {:reply, ["change_scene", 1, 411001]}, 20000,
    # {:reply, ["change_scene", 1, 102111]}, 20000
  ]

# config :pressure_test, serverlist_file: "./config/serverlist.txt"
# config :pressure_test, server_name: "long"

config :pressure_test, do_while: false
config :pressure_test, do_while_interval: 1   #min
config :pressure_test, while_reply: [
    # {:reply, ["gm:random_act_auction", 118, 1]}, 10000,
    # {:reply, ["battle_field:player_enter"]}, 1000,
    # {:reply, ["battle_field:player_leave"]}, 50000,
  ]

config :pressure_test, from_group_index: 0
config :pressure_test, group_index_addition: 10
config :pressure_test, wetest_api_num: 20
config :pressure_test, cowboy_port: 9999
config :pressure_test, not_log_heads: ["move"]
config :pressure_test, msg_begin_cfg: %{
  each_slice_num: 5,
  each_slice_delay: 15
}
# config :pressure_test, enter_array, %{
#   interval: 10,
#   enter_num: 50,
#   account_time: 6
# }

config :pressure_test, path_find_strategy: :not_fight       # [:near, :only_player]
config :pressure_test, wetest_api_false: :force             # :force 强制开启， int 尝试wetest次数
config :pressure_test, cfg_file_path: "./env.json"
config :pressure_test, need_move: false
