defmodule StartPressure do
  require Logger

  def go(name_prefix, from, to, born_state) do
    # StartPressure.go("bot_1_", 1, 1500, 1)
    start_some(name_prefix, from, to, born_state)
  end

  def start_single(name_prefix, id, born_state) do
    account = name_prefix <> "#{id}"

    case Realm.start_avatar(account, born_state) do
      {:ok, pid} ->
        pid

      _ ->
        nil
    end
  end

  def start_some(name_prefix, from_id, to_id, born_state) do
    # 初始化场景机器人
    start_single(name_prefix, from_id - 1, born_state)
    strategy(:once_time, name_prefix, from_id, to_id, born_state)
  end

  def strategy(:once_time, name_prefix, from_id, to_id, born_state) do
    from_id..to_id
    |> Enum.each(fn this_id ->
      # Process.sleep(300)
      start_single(name_prefix, this_id, born_state)
    end)
  end
end
