defmodule Gm do
  # ["gm:open_act", act_id, time]
  # ["gm", "god", 50]

  @spec gm(String.t(), integer, integer, list()) :: :ok
  def gm(name_prefix, from_id, to_id, params) do
    Enum.each(from_id..to_id, fn this_id ->
      account = name_prefix <> "#{this_id}"
      this_pid = Avatar.Ets.load_value(account)
      Router.route(this_pid, {:gm, params})
    end)
  end

  def atk() do
    Realm.broadcast({:atk})
  end

  def forward(name_prefix, from_id, to_id, x, y) do
    Enum.each(from_id..to_id, fn this_id ->
      account = name_prefix <> "#{this_id}"
      this_pid = Avatar.Ets.load_value(account)
      Router.route(this_pid, {:forward, x, y})
    end)
  end

  def attack(name_prefix, from_id, to_id, x, y, times, is_back?) do
    Enum.each(from_id..to_id, fn this_id ->
      account = name_prefix <> "#{this_id}"
      this_pid = Avatar.Ets.load_value(account)
      Router.route(this_pid, {:attack, x, y, times, is_back?})
    end)
  end

  def gacha(num) do
    Realm.broadcast({:gacha, num})
  end
end
