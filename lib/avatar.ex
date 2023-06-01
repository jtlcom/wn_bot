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

defmodule AvatarDef do
  defstruct id: 0,
            account: "",
            name: "",
            conn: nil,
            buildings: %{},
            city_pos: nil,
            gid: 0,
            grids: %{},
            grids_limit: 10,
            heros: %{},
            points: %{},
            troops: %{},
            units: %{},
            fixed_units: %{},
            dynamic_units: %{}
end

defmodule Avatar do
  use GenServer
  require Logger
  require Utils

  @loop_delay 5000
  def packet, do: 4

  def start_link(args, opts \\ []) do
    GenServer.start_link(__MODULE__, args, opts)
  end

  def init({server_ip, server_port, name, born_state}) do
    # IO.inspect id
    start_time = Utils.timestamp(:ms)
    name = "#{name}"
    Guid.register(self(), name)
    Process.put(:avatar_id, name)
    Process.put(:avatar_name, name)
    Process.put(:svr_aid, name)

    {:ok, conn} =
      :gen_tcp.connect(server_ip, server_port, [
        :binary,
        packet: packet(),
        active: true,
        recbuf: 1024 * 1024 * Application.get_env(:whynot_bot, :recv_buff, 20),
        keepalive: true,
        nodelay: true
      ])

    Client.send_msg(conn, ["login", name])
    Avatar.Ets.insert(name, self())

    end_time = Utils.timestamp(:ms)
    IO.inspect(end_time - start_time)

    Upload.log("conn: #{inspect(conn)},   robot: #{name}, init used: #{end_time - start_time}")

    {:ok, %AvatarDef{account: name, gid: born_state, conn: conn}}
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

  def handle_info({:tcp, socket, data}, %{id: id, account: account} = player) do
    decoded = SimpleMsgPack.unpack!(data)
    Logger.info("recvd message------------------------------------------------:
    \t\t avatar: \t #{id}
    \t\t account: \t #{account}
    \t\t from_ip: \t #{inspect(client_ip(socket))}
    \t\t time: \t #{inspect(:calendar.local_time())}
    \t\t msg: \t #{inspect(decoded, pretty: true, limit: :infinity)}
    ")

    {new_player} =
      case decoded do
        ["info", evts] ->
          AvatarEvent.handle_info(evts, player)

        ["login", svr_data] ->
          # Supervisor.which_children(Avatars)
          IO.puts("login!!!!!!!")
          new_player = player |> login_update(svr_data)
          Client.send_msg(player.conn, ["login_done"])
          MsgCounter.res_onlines_add()
          :erlang.send_after(@loop_delay, self(), {:loop})

          {new_player}

        data ->
          # IO.inspect data
          case handle_info(data, player) do
            {:noreply, new_player} ->
              {new_player}

            _ ->
              {player}
          end
      end

    {:noreply, new_player}
  end

  def handle_info({:loop}, %{} = player) do
    new_player =
      case AvatarLoop.loop(player) do
        {:ok, new_player} ->
          :erlang.send_after(@loop_delay, self(), {:loop})
          new_player

        {:sleep, min} ->
          IO.puts("sleep sleep  sleep  sleep  sleep")
          IO.puts("sleep sleep  sleep  sleep  sleep")
          :erlang.send_after(min * 60 * 1_000, self(), {:loop})
          player
      end

    {:noreply, new_player}
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

  def handle_info(["evt" | event_msg], player) do
    player1 =
      event_msg
      |> Enum.reduce(player, fn each_event_msg, acc ->
        AvatarEvent.handle_event(each_event_msg, acc)
      end)

    {:noreply, player1}
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

  def handle_cast({:forward, x, y}, player) do
    troop_guid = player |> Map.get(:troops, %{}) |> Map.keys() |> Enum.min()
    pos = [x, y]
    Client.send_msg(player.conn, ["op", "forward", [troop_guid, pos]])
    IO.puts("troop_guid: #{inspect(troop_guid)}}")
    IO.puts("pos: #{inspect(pos)}}")
    {:noreply, player}
  end

  def handle_cast({:attack, x, y, times, is_back?}, player) do
    troop_guid = player |> Map.get(:troops, %{}) |> Map.keys() |> Enum.min()
    pos = [x, y]
    Client.send_msg(player.conn, ["op", "attack", [troop_guid, pos, times, is_back?]])
    IO.puts("troop_guid: #{inspect(troop_guid)}}")
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

  def login_update(player, svr_data) do
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

    %AvatarDef{
      player
      | buildings: buildings,
        city_pos: city_pos,
        gid: gid,
        grids: grids,
        grids_limit: grids_limit,
        heros: heros,
        id: id,
        name: name,
        points: points,
        troops: troops
    }
  end

  def analyze_verse(player, type) do
    case type do
      :attack ->
        player.units
        |> Enum.map(fn
          {pos, %{"aid" => aid} = _pos_data} ->
            if aid == player.id, do: pos, else: nil

          _ ->
            nil
        end)
        |> Enum.reject(&is_nil/1)
        |> Enum.random()

      :forward ->
        player.units
        |> Enum.map(fn
          {pos, %{"aid" => aid} = _pos_data} ->
            if aid == player.id, do: pos, else: nil

          _ ->
            nil
        end)
        |> Enum.reject(&is_nil/1)
        |> Enum.random()

      _ ->
        :ok
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
