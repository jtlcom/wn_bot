# 机器人

--- 

## HTTP操作

- 使用postman并import此文件([点击下载](wn_bot.postman_collection.json))

## Shell操作

- 拉取依赖 mix deps.get
- 开服: mix clean -- all && iex -S mix
- 机器人登录: StartPressure.go(ip, port, name_prefix, from, to, born_state)
- 使用GM: Gm.gm(name_prefix, from, to, params)
- 行军: Gm.forward(name_prefix, from, to, to_x, to_y, index)
- 攻占: Gm.attack(name_prefix, from, to, to_x, to_y, index, times, is_back?)

---
