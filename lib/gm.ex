defmodule Gm do
  @spec gm(String.t(), integer, integer, list()) :: :ok
  def gm(name_prefix, from_id, to_id, params) do
    Enum.each(from_id..to_id, fn this_id ->
      account = name_prefix <> "#{this_id}"
      this_pid = Avatar.Ets.load_value(account) |> Map.get(:pid)
      Router.route(this_pid, {:gm, params})
    end)
  end

  def atk() do
    Realm.broadcast({:atk})
  end

  def forward(name_prefix, from_id, to_id, x, y, 0) do
    Enum.each(1..5, fn this_index ->
      forward(name_prefix, from_id, to_id, x, y, this_index)
      Process.sleep(1500)
    end)
  end

  def forward(name_prefix, from_id, to_id, x, y, troop_index) do
    Enum.each(from_id..to_id, fn this_id ->
      account = name_prefix <> "#{this_id}"
      this_pid = Avatar.Ets.load_value(account) |> Map.get(:pid)
      Router.route(this_pid, {:forward, x, y, troop_index})
    end)
  end

  def attack(name_prefix, from_id, to_id, x, y, 0, times, is_back?) do
    Enum.each(1..5, fn this_index ->
      attack(name_prefix, from_id, to_id, x, y, this_index, times, is_back?)
      Process.sleep(1500)
    end)
  end

  def attack(name_prefix, from_id, to_id, x, y, troop_index, times, is_back?) do
    Enum.each(from_id..to_id, fn this_id ->
      account = name_prefix <> "#{this_id}"
      this_pid = Avatar.Ets.load_value(account) |> Map.get(:pid)
      Router.route(this_pid, {:attack, x, y, troop_index, times, is_back?})
    end)
  end

  def summon(name_prefix, from_id, to_id, x, y, 0, is_main_team) do
    Enum.each(1..5, fn this_index ->
      summon(name_prefix, from_id, to_id, x, y, this_index, is_main_team)
      Process.sleep(1500)
    end)
  end

  def summon(name_prefix, from_id, to_id, x, y, troop_index, is_main_team) do
    Enum.each(from_id..to_id, fn this_id ->
      account = name_prefix <> "#{this_id}"
      this_pid = Avatar.Ets.load_value(account) |> Map.get(:pid)
      Router.route(this_pid, {:summon, x, y, troop_index, is_main_team})
    end)
  end

  def gacha(num) do
    Realm.broadcast({:gacha, num})
  end
end
