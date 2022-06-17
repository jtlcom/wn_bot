defmodule StartConfig do
  require Logger

  def log(msg) do
    # inspect(msg, [syntax_colors: [number: :red, atom: :red, tuple: :red, map: :red, list: :red], pretty: true])
    inspect msg
  end

  def trans_from_decode(cfgs) do
    cfgs
    |> Map.update(:ip, get_config(:ip, '127.0.0.1'), &String.to_charlist/1)
    |> Map.update(:path_find_strategy, get_config(:path_find_strategy, :not_fight), &String.to_atom/1)
    |> Map.update(:strategy, get_config(:strategy, 'once_time'), &String.to_charlist/1)
  end

  def init_config() do
    with cfg_file_path = get_config(:cfg_file_path, "./小丑.txt"),
      true <- File.exists?(cfg_file_path),
      {:ok, lala} = File.read(cfg_file_path),
      %{} = cfgs_by_file <- Jason.decode!(lala) |> GameDef.to_atom_key() |> trans_from_decode()
    do
      cfgs_by_file
      |> Enum.each(fn {k, v} ->
        Application.put_env(:pressure_test, k, v)
      end)
      IO.inspect(cfgs_by_file, pretty: true)
      Logger.warn "#{log 88888888888} load_file_cfg: #{log cfgs_by_file}"
    end
  end

  def save_config() do
    cfgs = %{
      ip: '172.18.188.183' |> List.to_string,
      port: 6666,
      start_id: 1,
      start_num: 5,
      chat_num: 0,
      need_move: false,
      path_find_strategy: Atom.to_string(:not_fight),
      cowboy_port: 9999,
      robot_gene: [11, 22, 32],
      strategy: 'once_time' |> List.to_string,
      leave_after: 120,
      enter_delay: 100,
      addition: 5,
      not_log_heads: ["move"],
      log_to_file: true,
      msg_begin_cfg: %{
        each_slice_num: 2,
        each_slice_delay: 1000
      }
    }
    File.write(get_config(:cfg_file_path, "./小丑.txt"), Jason.encode!(cfgs))
  end

  def name_file_path() do
    get_config(:name_file_path, "name.json")
  end

  def names() do
    name_file_path()
    |> File.read!()
    |> Jason.decode!()
  end

  def not_log_heads() do
    get_config(:not_log_heads, [])
  end

  def msg_begin_cfg() do
    get_config(:msg_begin_cfg, %{})
  end

  def log_to_file() do
    get_config(:log_to_file, false)
  end

  def server_ip_port() do
    [get_config(:ip, '127.0.0.1'), get_config(:port, 6666)]
  end

  def need_move?() do
    get_config(:need_move, false)
  end

  def strategy() do
    get_config(:strategy, "once_time")
  end

  def start_id() do
    get_config(:start_id, 600000)
  end

  def robot_num() do
    get_config(:start_num, 0)
  end

  def chat_robot_num() do
    get_config(:chat_broadcast_num, 0)
  end

  def enter_delay() do
    get_config(:enter_delay, 10)
  end

  def enter_array() do
    get_config(:enter_array, %{}) |> Map.new()
  end

  def robot_machine() do
    get_config(:robot_machine, 'machine_default')
  end

  def leave_after() do
    get_config(:leave_after, 1)
  end

  def get_config(key, default_val) do
    case Application.get_all_env(:kernel) do
      nil ->
        Application.get_env(:pressure_test, key, default_val)
      list ->
        case list[key] do
          nil ->
            Application.get_env(:pressure_test, key, default_val)
          val ->
            val
        end
    end
  end

end
