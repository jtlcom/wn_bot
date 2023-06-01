# 机器人

--- 

## HTTP操作

- IP/PORT: 192.168.1.129:6666
- 获取连接信息: [GET, /get_info]
- 上传连接信息: [POST, /save_info, %{ip: string, port: int, name_prefix: string, from: int, to: int, born_state: int}]
- 机器人登录: [POST, /login, %{}]
- 使用GM: [POST, /gm, %{params: [string]}]
- 行军: [POST, /forward, %{x: int, y: int}]
- 攻占: [POST, /attack, %{x: int, y: int, times: int, is_back?: boolean}]

## Shell操作

- 拉取依赖 
- 开服: mix clean -- all && iex -S mix
- 机器人登录: StartPressure.go(ip, port, name_prefix, from, to, born_state)
- 使用GM: Gm.gm(name_prefix, from, to, params)
- 行军: Gm.forward(name_prefix, from, to, to_x, to_y)
- 攻占: Gm.attack(name_prefix, from, to, to_x, to_y, times, is_back?)

---
