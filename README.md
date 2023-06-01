# 机器人

--- 

## HTTP操作

- IP/PORT: 192.168.1.129:9999
- 获取连接信息: [GET, /get_info]
- 上传连接信息: [POST, /save_info, %{ip: string, port: int, name_prefix: string, from: int, to: int, born_state: int}]
- 机器人登录: [POST, /login, %{}]
- 使用GM: [POST, /gm, %{params: [string]}]
- 行军: [POST, /forward, %{x: int, y: int, index: troop_index}]
- 攻占: [POST, /attack, %{x: int, y: int, index: troop_index, times: int, is_back?: boolean}]

## Shell操作

- 拉取依赖 mix deps.get
- 开服: mix clean -- all && iex -S mix
- 机器人登录: StartPressure.go(ip, port, name_prefix, from, to, born_state)
- 使用GM: Gm.gm(name_prefix, from, to, params)
- 行军: Gm.forward(name_prefix, from, to, to_x, to_y, index)
- 攻占: Gm.attack(name_prefix, from, to, to_x, to_y, index, times, is_back?)

---
