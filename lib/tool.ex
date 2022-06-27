defmodule Tool do
  # @guard_state 1
  # @do_nothing 8
  @statistics_name :lala

  def robot_num() do
    Debug.onlines() |> length()
  end

  def logout_robot(from, num) do
    from..(from + num)
    |> Enum.each(&Router.route(&1, :login_out))
  end

  def stop() do
    WeTestApi.stop_test()
  end

  def logout() do
    Realm.broadcast_each_delay(:login_out, 100)
  end

  def get_title_num(title) do
    key = title |> String.replace(" ", "_") |> String.to_atom()
    Keyword.get(:ets.lookup(@statistics_name, key), key) || 0
  end

  @sleep_ms 120 * 1000
  def do_while_enter() do
    pid =
      spawn(fn ->
        do_loop()
      end)

    Process.put(:do_while_enter, pid)
  end

  def do_loop() do
    Process.sleep(@sleep_ms)
    do_loop()
  end

  def lv(lv, lines \\ :all) do
    ["gm:level", lv]
    |> Realm.broadcast_avatars(lines)
  end

  # [:near, :only_player, :not_fight]
  def set_fight_strategy(strategy) do
    Application.put_env(:pressure_test, :path_find_strategy, strategy)
  end
end
