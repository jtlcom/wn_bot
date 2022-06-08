defmodule Tool do

  # @guard_state 1
  # @do_nothing 8
  @statistics_name :lala
  @gm_equips %{1 => [201999992], 2 => [201999993], 3 => [201999994]}

  def robot_num() do
    Debug.onlines() |> length()
  end

  def set_state(num, state \\ 0) do
    {:set_robot_state, state}
    |> Realm.broadcast_avatars_handle({:by_num, num})
  end

  def logout_robot(from, num) do
    (from..(from + num))
    |> Enum.each(&(Router.route(&1, :login_out)))
  end

  def stop() do
    WeTestApi.stop_test()
  end

  def move() do
    Realm.broadcast({:set_robot_state, 0})
  end

  def not_move() do
    Realm.broadcast({:set_robot_state, 8})
  end

  def logout() do
    Realm.broadcast_each_delay(:login_out, 100)
  end

  def get_title_num(title) do
    key = title |> String.replace(" ", "_") |> String.to_atom
    Keyword.get(:ets.lookup(@statistics_name, key), key) || 0
  end

  def change_scene(scene, lines \\ :all) do
    ["change_scene", scene]
    |> Realm.broadcast_avatars(lines)
  end

  def change_pos(x, y, lines \\ :all) do
    {:change_pos, x, y}
    |> Realm.broadcast_avatars_handle(lines)
  end

  @sleep_ms 120 * 1000
  def do_while_enter() do
    pid = spawn(fn ->
      do_loop()
    end)
    Process.put(:do_while_enter, pid)
  end

  def do_loop() do
      IO.inspect "main_city enter"
      MainCity.enter({:by_num, 198})
      Process.sleep(@sleep_ms)
      IO.inspect "cross_map enter"
      WildBossZone.enter 423001, {:by_num, 198}
      Process.sleep(@sleep_ms)
      do_loop()
  end

  def lv(lv, lines \\ :all) do
    ["gm:level", lv]
    |> Realm.broadcast_avatars(lines)
  end

  def set_fight_strategy(strategy) do       # [:near, :only_player, :not_fight]
    Application.put_env(:pressure_test, :path_find_strategy, strategy)
  end

  def equip_all(lines \\ :all) do
    Equipment.equip(lines)
  end

  def add_item(class_ids, lines \\ :all)
  def add_item(class_ids, lines) when is_map(class_ids) do
    Realm.broadcast({:tool_add_item, class_ids}, lines)
  end

  def add_item(:gm, lines) do
    Realm.broadcast({:tool_add_item, @gm_equips}, lines)
  end

  def equip_random(num, lines \\ :all) do
    {:gm_equip_random, num}
    |> Realm.broadcast_avatars_handle(lines)
  end

end