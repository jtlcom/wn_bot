defmodule Avatar.Supervisor do
  use Supervisor
  @name Avatars

  def start_link() do
    Supervisor.start_link(__MODULE__, [], name: @name)
  end

  def start_child(args, opts \\ []) do
    Supervisor.start_child(@name, [args, opts])
  end

  def init([]) do
    children = [worker(Avatar, [], restart: :temporary)]
    supervise(children, strategy: :simple_one_for_one)
  end

  def broadcast(msg) do
    Supervisor.which_children(@name)
    |> Enum.each(fn {_name, pid, type, _modules} = _child ->
      (type == :worker && GenServer.cast(pid, msg)) || :ok
    end)
  end
end

defmodule Avatar do
  use GenServer
  require Logger
  require Utils

  def packet, do: 4

  def start_link(args, opts \\ []) do
    GenServer.start_link(__MODULE__, args, opts)
  end

  def init({server_ip, server_port, name, born_state, ai}) do
    Logger.info("name: #{inspect(name)}, ip: #{inspect(server_ip)}, pt: #{inspect(server_port)}")
    Router.cast(self(), {:login, {server_ip, server_port, name, born_state, ai}})
    {:ok, %{name: name, born_state: born_state}}
  end

  # -------------------------------- handle_info ----------------------------------
  def handle_info({:tcp_closed, _socket}, player) do
    Logger.info("tcp closed!")
    {:stop, {:shutdown, :tcp_closed}, player}
  end

  def handle_info({:tcp_error, _, reason}, player) do
    Logger.info("tcp error!")
    {:stop, {:shutdown, {:tcp_error, reason}}, player}
  end

  def handle_info(:timeout, player) do
    Logger.info("conn time out!")
    {:stop, {:shutdown, :tcp_timeout}, player}
  end

  def handle_info(
        {:tcp, socket, data},
        %AvatarDef{id: id, account: account, gid: born_state, conn: conn} = player
      ) do
    decoded = SimpleMsgPack.unpack!(data)
    Logger.debug("recvd message------------------------------------------------:
    \t\t avatar: \t #{id}
    \t\t account: \t #{account}
    \t\t from_ip: \t #{inspect(client_ip(socket))}
    \t\t time: \t #{inspect(:calendar.local_time())}
    \t\t msg: \t #{inspect(decoded, pretty: true, limit: :infinity)}
    ")

    new_player =
      case decoded do
        ["info", ["login:choose_born_state", _id, _params]] ->
          Process.put(:new, true)
          Client.send_msg(conn, ["login:choose_born_state", born_state])
          player

        ["info" | event_msg] ->
          event_msg
          |> Enum.reduce(player, fn each_event_msg, acc ->
            AvatarEvent.handle_event(each_event_msg, acc)
          end)
          |> case do
            %AvatarDef{} = new_player ->
              new_player

            _ ->
              player
          end

        ["evt" | event_msg] ->
          event_msg
          |> Enum.reduce(player, fn each_event_msg, acc ->
            AvatarEvent.handle_event(each_event_msg, acc)
          end)
          |> case do
            %AvatarDef{} = new_player ->
              new_player

            _ ->
              player
          end

        ["login", svr_data] ->
          # Supervisor.which_children(Avatars)
          case player |> login_update(svr_data) do
            %AvatarDef{city_pos: city_pos, conn: conn} = new_player ->
              Client.send_msg(conn, ["login_done"])
              Client.send_msg(conn, ["see", city_pos, 10])
              Process.put(:svr_aid, new_player.id)
              Avatar.Ets.insert(account, %{pid: self(), aid: new_player.id})
              MsgCounter.res_onlines_add()
              Process.send_after(self(), {:loop}, 5000)
              new_player

            _ ->
              player
          end

        _ ->
          player
      end

    {:noreply, new_player}
  end

  def handle_info({:loop}, %AvatarDef{conn: conn, city_pos: city_pos, AI: ai} = player) do
    now = System.system_time(:second)
    last_op_ts = Process.get(:last_op_ts, 0)
    delta_sec = trunc(now - last_op_ts)
    Process.send_after(self(), {:loop}, 5000)
    Client.send_msg(conn, ["ping", 1])

    cond do
      Process.get(:new, false) ->
        Process.put(:new, false)
        Client.send_msg(conn, ["gm", "god"])
        Client.send_msg(conn, ["gm", "init_bot"])
        {:noreply, player}

      ai and delta_sec >= 15 ->
        Process.put(:last_op_ts, now)
        Client.send_msg(conn, ["see", city_pos, 10])

        new_player =
          case AvatarLoop.loop(player) do
            {:ok, new_player} -> new_player
            _ -> player
          end

        {:noreply, new_player}

      true ->
        # Logger.info("player: #{inspect(player.units, pretty: true, limit: :infinity)}")
        # Logger.info("player: #{inspect(player.fixed_units, pretty: true, limit: :infinity)}")
        {:noreply, player}
    end
  end

  def handle_info({:reply, msg}, %{conn: conn} = player) do
    [head | _] = ex_msg = msg

    with [module | _] <- String.split(head, ":"),
         true <- module == "gm" do
      Client.send_msg(conn, ex_msg)
    else
      _ ->
        # start_time = Utils.timestamp(:ms)
        # Process.put(head, Utils.timestamp(:ms))
        Client.send_msg(conn, ex_msg)
        # end_time = Utils.timestamp(:ms)
    end

    {:noreply, player}
  end

  def handle_info(_msg, player) do
    # Logger.info "what msg #{inspect msg}"
    {:noreply, player}
  end

  def handle_cast({:atk}, player) do
    troop_guid = player |> Map.get(:troops, %{}) |> Map.keys() |> Enum.min()
    pos = analyze_verse(player, :attack)
    Client.send_msg(player.conn, ["op", "forward", [troop_guid, pos]])
    IO.puts("atk atk atk atk atk}")
    IO.puts("troop_guid: #{inspect(troop_guid)}}")
    IO.puts("pos: #{inspect(pos)}}")
    {:noreply, player}
  end

  def handle_cast({:apply, type, params}, player) do
    Client.send_msg(player.conn, List.wrap(type) ++ List.wrap(params))
    {:noreply, player}
  end

  def handle_cast({:forward, x, y, troop_index}, player) do
    troop_guid =
      player |> Map.get(:troops, %{}) |> Map.keys() |> Enum.sort() |> Enum.at(troop_index - 1)

    pos = [x, y]
    Client.send_msg(player.conn, ["op", "forward", [troop_guid, pos]])
    IO.puts("troop_guid: #{inspect(troop_guid)}}")
    IO.puts("pos: #{inspect(pos)}}")
    {:noreply, player}
  end

  def handle_cast({:attack, x, y, troop_index, times, is_back?}, player) do
    troop_guid =
      player |> Map.get(:troops, %{}) |> Map.keys() |> Enum.sort() |> Enum.at(troop_index - 1)

    pos = [x, y]
    Client.send_msg(player.conn, ["op", "attack", [troop_guid, pos, times, is_back?]])
    IO.puts("troop_guid: #{inspect(troop_guid)}}")
    {:noreply, player}
  end

  def handle_cast({:summon, x, y, troop_index, is_main_team}, player) do
    troop_guid =
      player |> Map.get(:troops, %{}) |> Map.keys() |> Enum.sort() |> Enum.at(troop_index - 1)

    pos = [x, y]
    Client.send_msg(player.conn, ["op", "join_summon", [troop_guid, pos, is_main_team]])
    IO.puts("troop_guid: #{inspect(troop_guid)}}")
    {:noreply, player}
  end

  def handle_cast({:stop, troop_index}, player) do
    troop_guid =
      player |> Map.get(:troops, %{}) |> Map.keys() |> Enum.sort() |> Enum.at(troop_index - 1)

    Client.send_msg(player.conn, ["op", "stop", [troop_guid]])
    IO.puts("troop_guid: #{inspect(troop_guid)}}")
    {:noreply, player}
  end

  def handle_cast({:defend, troop_index, x, y}, player) do
    troop_guid =
      player |> Map.get(:troops, %{}) |> Map.keys() |> Enum.sort() |> Enum.at(troop_index - 1)

    pos = [x, y]
    Client.send_msg(player.conn, ["op", "defend", [troop_guid, pos]])
    IO.puts("troop_guid: #{inspect(troop_guid)}}")
    {:noreply, player}
  end

  def handle_cast({:back, troop_index}, player) do
    troop_guid =
      player |> Map.get(:troops, %{}) |> Map.keys() |> Enum.sort() |> Enum.at(troop_index - 1)

    Client.send_msg(player.conn, ["op", "back", [troop_guid]])
    IO.puts("troop_guid: #{inspect(troop_guid)}}")
    {:noreply, player}
  end

  def handle_cast({:build, build_id}, %AvatarDef{grids: grids} = player) do
    Enum.find(grids, fn
      {_this_pos, %{"tid" => 1} = _this_data} -> true
      _ -> false
    end)
    |> case do
      {this_pos, _this_data} ->
        Client.send_msg(player.conn, ["op", "build", [this_pos, build_id, "营帐"]])
        IO.puts("pos: #{inspect(this_pos)}")
        {:noreply, player}

      _ ->
        {:noreply, player}
    end
  end

  def handle_cast({:faction_arena_battle, index}, player) do
    index = (index == 0 && Enum.random(1..10)) || index
    Client.send_msg(player.conn, ["faction_arena", "battle", index, 0])
    {:noreply, player}
  end

  def handle_cast({:gm, params}, player) do
    IO.puts("#{player.account}: params: #{inspect(params)}}")
    Client.send_msg(player.conn, ["gm"] ++ params)
    {:noreply, player}
  end

  def handle_cast({:gacha, num}, player) do
    Client.send_msg(player.conn, ["hero:gacha", 1, num])
    IO.puts("gacha gacha gacha gacha gacha}")
    {:noreply, player}
  end

  def handle_cast({:reply, msg}, %{conn: conn, id: _id} = player) do
    [head | _] = ex_msg = msg

    # Logger.info ex_msg
    with [module | _] <- String.split(head, ":"),
         true <- module == "gm" do
      Client.send_msg(conn, ex_msg)
    else
      _ ->
        # start_time = Utils.timestamp(:ms)
        # Process.put(head, Utils.timestamp(:ms))
        Client.send_msg(conn, ex_msg)
        Process.put(head, Utils.timestamp(:ms))
        # end_time = Utils.timestamp(:ms)
    end

    {:noreply, player}
  end

  def handle_cast({:reply, msg, delay}, %{conn: _conn} = player) do
    Logger.info("reply to server: #{inspect(msg)}, delay: #{delay}")
    Process.send_after(self(), {:reply, msg}, delay + :rand.uniform(5000))
    {:noreply, player}
  end

  def handle_cast(msg, %{conn: conn} = player) do
    # start_time = Utils.timestamp(:ms)

    {ex_msg, new_player} =
      case msg do
        _ ->
          {msg, player}
      end

    Logger.info("#{inspect(ex_msg)}")
    Client.send_msg(conn, ex_msg)
    # end_time = Utils.timestamp(:ms)
    {:noreply, new_player}
  end

  def handle_cast(_msg, player) do
    {:noreply, player}
  end

  def log(msg, data) do
    File.write("quiz.txt", "#{inspect(msg)}\n#{inspect(data)}\n\n", [:append])
  end

  # -------------------------------------------------------------------------------

  def terminate(:normal, %{conn: conn} = _player) do
    Logger.info("avatar ternimate")
    MsgCounter.res_onlines_sub()
    # start_time = Utils.timestamp(:ms)

    :gen_tcp.close(conn)
    # end_time = Utils.timestamp(:ms)
    :ok
  end

  def terminate({:shutdown, reason}, %{conn: conn} = player) do
    Logger.info(
      "terminate no normal, id is #{player.id}, reason is #{inspect(reason)}, data is #{inspect(player)}"
    )

    MsgCounter.res_onlines_sub()
    # start_time = Utils.timestamp(:ms)

    :gen_tcp.close(conn)
    # end_time = Utils.timestamp(:ms)
    :ok
  end

  def terminate(_, _player) do
    MsgCounter.res_onlines_sub()
    :ok
  end

  def login_update(%AvatarDef{} = player, svr_data) do
    buildings = Map.get(svr_data, "buildings")
    city_pos = Map.get(svr_data, "city_pos")
    gid = Map.get(svr_data, "gid")
    grids = Map.get(svr_data, "grids")
    grids_limit = Map.get(svr_data, "grids_limit")
    heros = Map.get(svr_data, "heros")
    id = Map.get(svr_data, "id")
    name = Map.get(svr_data, "name")
    points = Map.get(svr_data, "points")
    troops = Map.get(svr_data, "troops")

    struct(player, %{
      buildings: buildings,
      city_pos: city_pos,
      gid: gid,
      grids: grids,
      grids_limit: grids_limit,
      heros: heros,
      id: id,
      name: name,
      points: points,
      troops: troops
    })
  end

  def analyze_verse(%AvatarDef{units: units} = player, type) do
    case map_size(units) > 0 and type do
      :attack ->
        total_pos =
          units
          |> Enum.flat_map(fn
            {pos, %{"aid" => aid} = _pos_data} -> if aid == player.id, do: [pos], else: []
            _ -> []
          end)

        if length(total_pos) > 0, do: Enum.random(total_pos), else: nil

      :forward ->
        total_pos =
          units
          |> Enum.flat_map(fn
            {pos, %{"aid" => _aid} = _pos_data} -> [pos]
            _ -> []
          end)

        if length(total_pos) > 0, do: Enum.random(total_pos), else: nil

      _ ->
        nil
    end
  end

  defp client_ip(socket) do
    case :inet.peername(socket) do
      {:ok, {client_ip, _port}} ->
        client_ip

      _ ->
        ""
    end
  end
end
