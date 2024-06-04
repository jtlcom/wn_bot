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

  def start_link(args, opts \\ []) do
    GenServer.start_link(__MODULE__, args, opts)
  end

  def init({server_ip, server_port, name, gid, ai}) do
    Logger.info(
      "account: #{inspect(name)}, ip: #{inspect(server_ip)}, pt: #{inspect(server_port)}"
    )

    Process.send_after(self(), :login, 1000)

    {:ok,
     %AvatarDef{
       account: name,
       gid: gid,
       server_ip: server_ip,
       server_port: server_port,
       AI: ai
     }}
  end

  # -------------------------------- handle_info ----------------------------------
  def handle_info(
        :login,
        %AvatarDef{
          account: name,
          server_ip: server_ip,
          server_port: server_port
        } = player
      ) do
    begin_time = Utils.timestamp(:ms)

    case Client.login_post(server_ip, name) do
      {:ok, %{body: body}} ->
        case Jason.decode!(body) do
          %{"login_with_data" => login_with_data, "token" => token} ->
            claim = Jason.encode!(login_with_data)
            start_time = Utils.timestamp(:ms)
            name = "#{name}"
            Guid.register(self(), name)
            Process.put(:account, name)
            Process.put(:last_op_ts, Utils.timestamp())
            Process.put(:encrypt_key, encrypt_key(token))

            case Client.tcp_connect(server_ip, server_port) do
              {:ok, conn} ->
                Client.send_msg(conn, ["login", name, 0, token, claim, false], false)
                end_time = Utils.timestamp(:ms)

                Logger.info("log conn: #{inspect(conn)},   robot: #{name},
        total used: #{end_time - begin_time},
        login: #{start_time - begin_time},
        connect: #{end_time - start_time}")

                Count.Ets.insert(name, %{
                  total: end_time - begin_time,
                  login: start_time - begin_time,
                  connect: end_time - start_time
                })

                {:ok, struct(player, %{conn: conn, token: token, claim: claim})}

              _ ->
                :error3
            end

          _ ->
            :error2
        end

      {:error, _error} ->
        :error1
    end
    |> case do
      {:ok, new_player} ->
        {:noreply, new_player}

      error ->
        Logger.warning("avatar login failed, error:#{error}, state:#{inspect(player)}")
        Process.send_after(self(), :login, 1000)
        Process.put(:cmd_dic, -1)
        {:noreply, player}
    end
  end

  def handle_info(
        :loop,
        %AvatarDef{
          id: aid,
          conn: conn,
          city_pos: city_pos,
          AI: ai,
          account: name,
          server_ip: server_ip,
          server_port: server_port,
          token: token,
          loop_ref: _,
          claim: claim
        } = player
      ) do
    last_ts = Process.get(:last_op_ts, 0)
    Client.send_msg(conn, ["ping", 1])
    player = struct(player, %{loop_ref: nil})

    new_player =
      cond do
        Process.get(:new, false) ->
          Process.put(:new, false)
          Client.send_msg(conn, ["gm", "god"])
          Process.sleep(500)
          Client.send_msg(conn, ["gm", "init_bot"])
          Process.sleep(500)
          Client.send_msg(conn, ["gm", "god_func"])
          new_ref = Process.send_after(self(), :loop, 1000)
          struct(player, %{loop_ref: new_ref})

        ai == 1 ->
          op_index = Process.get(:op_index, 0)
          op_list = OpList.list(1)

          case Enum.at(op_list, op_index) do
            {now_ms, params} when is_list(params) ->
              new_params = Avatar.trans_params(params, player)

              Logger.debug("op_index: #{op_index}, new_params: #{inspect(new_params)}")
              Client.send_msg(conn, new_params)
              Process.put(:op_index, op_index + 1)

              case Enum.at(op_list, op_index + 1) do
                {new_ms, params} when is_list(params) ->
                  new_ref = Process.send_after(self(), :loop, new_ms - now_ms)
                  struct(player, %{loop_ref: new_ref})

                _ ->
                  new_ref = Process.send_after(self(), :loop, 5000)
                  struct(player, %{AI: true, loop_ref: new_ref})
              end

            _ ->
              new_ref = Process.send_after(self(), :loop, 5000)
              struct(player, %{AI: true, loop_ref: new_ref})
          end

        ai == 2 ->
          Client.tcp_close(conn)

          case Client.tcp_connect(server_ip, server_port) do
            {:ok, conn} ->
              Client.send_msg(conn, ["login", name, aid, token, claim, true], false)
              now = Utils.timestamp()
              Process.put(:last_op_ts, now)
              new_ref = Process.send_after(self(), :loop, 1000)
              struct(player, %{conn: conn, loop_ref: new_ref})

            _ ->
              Logger.warning("tcp_connect failed")
              new_ref = Process.send_after(self(), :loop, 1000)
              struct(player, %{loop_ref: new_ref})
          end

        ai and trunc(Utils.timestamp() - last_ts) >= 5 ->
          Client.send_msg(conn, ["see", city_pos, 2, 14])
          Process.sleep(500)
          Client.send_msg(conn, ["see", city_pos, 1, 8])
          Process.sleep(500)

          new_player =
            case AvatarLoop.loop(player) do
              {:ok, new_player} -> new_player
              _ -> player
            end

          now = Utils.timestamp()
          Process.put(:last_op_ts, now)
          new_ref = Process.send_after(self(), :loop, 5000)
          struct(new_player, %{loop_ref: new_ref})

        true ->
          new_ref = Process.send_after(self(), :loop, 5000)
          struct(player, %{loop_ref: new_ref})
      end

    {:noreply, new_player}
  end

  def handle_info(
        {:tcp, socket, data},
        %AvatarDef{id: id, account: account, gid: gid, conn: conn} = player
      ) do
    decoded = SimpleMsgPack.unpack!(data)
    Logger.debug("recvd message------------------------------------------------:
    \t\t avatar: \t #{id}
    \t\t account: \t #{account}
    \t\t from_ip: \t #{inspect(client_ip(socket))}
    \t\t time: \t #{inspect(:calendar.local_time())}
    \t\t msg: \t #{inspect(decoded, pretty: true, limit: :infinity)}
    ")

    case decoded do
      ["stop", "server closed"] ->
        {:stop, {:shutdown, :tcp_closed}, player}

      ["info", ["login:choose_born_state", _id, _params]] ->
        Process.put(:new, true)
        Client.send_msg(conn, ["login:choose_born_state", gid])
        {:noreply, player}

      ["info" | event_msg] ->
        event_msg
        |> Enum.reduce(player, fn each_event_msg, acc ->
          AvatarEvent.handle_event(each_event_msg, acc)
        end)
        |> case do
          %AvatarDef{} = new_player ->
            {:noreply, new_player}

          _ ->
            {:noreply, player}
        end

      ["evt" | event_msg] ->
        event_msg
        |> Enum.reduce(player, fn each_event_msg, acc ->
          AvatarEvent.handle_event(each_event_msg, acc)
        end)
        |> case do
          %AvatarDef{} = new_player ->
            {:noreply, new_player}

          _ ->
            {:noreply, player}
        end

      ["login", svr_data] ->
        # Supervisor.which_children(Avatars)
        case player |> login_update(svr_data) do
          %AvatarDef{city_pos: city_pos, conn: conn} = new_player ->
            Client.send_msg(conn, ["login_done"])
            Client.send_msg(conn, ["see", city_pos, 1, 7])
            Client.send_msg(conn, ["mail:list", "system", 0])
            Process.put(:svr_aid, new_player.id)
            Avatar.Ets.insert(account, %{pid: self(), aid: new_player.id})
            MsgCounter.res_onlines_add()
            new_ref = Process.send_after(self(), :loop, 5000)
            new_player = struct(new_player, %{loop_ref: new_ref, login_finish: true})
            {:noreply, new_player}

          _ ->
            {:noreply, player}
        end

      _ ->
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

  def handle_info({:tcp_closed, socket}, player) do
    socket != nil && Logger.error("tcp closed!")
    socket != nil && Logger.info("tcp closed: socket: #{inspect(socket)}")

    case reconnect(player) do
      {:ok, new_player} ->
        {:noreply, new_player}

      {:failed, %AvatarDef{reconnect_times: r_times} = new_player} when r_times < 100 ->
        Process.sleep(1000)
        handle_info({:tcp_closed, nil}, new_player)

      _ ->
        {:stop, {:shutdown, :tcp_closed}, player}
    end
  end

  def handle_info({:tcp_error, socket, reason}, player) do
    socket != nil && Logger.error("tcp error!")

    case reconnect(player) do
      {:ok, new_player} ->
        {:noreply, new_player}

      {:failed, %AvatarDef{reconnect_times: r_times} = new_player} when r_times < 100 ->
        Process.sleep(1000)
        handle_info({:tcp_error, nil, reason}, new_player)

      _ ->
        {:stop, {:shutdown, {:tcp_error, reason}}, player}
    end
  end

  def handle_info(:timeout, player) do
    Logger.info("conn time out!")
    {:stop, {:shutdown, :tcp_timeout}, player}
  end

  def handle_info(_msg, player) do
    # Logger.info "what msg #{inspect msg}"
    {:noreply, player}
  end

  def handle_cast({:logout}, player) do
    {:stop, :normal, player}
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
    new_params = Avatar.trans_params(List.wrap(params), player)
    Client.send_msg(player.conn, List.wrap(type) ++ new_params)
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
    Client.send_msg(player.conn, ["tile_detail", pos])
    Process.sleep(500)
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

  def handle_cast(
        {:kill_monster},
        %AvatarDef{conn: conn, dynamic_units: dynamic_units, troops: troops} = player
      ) do
    Enum.reduce_while(dynamic_units, 0, fn
      {_guid, %{"type" => 3, "pos" => this_pos}}, acc ->
        Enum.each(troops, fn
          {this_troop_guid, _} ->
            Client.send_msg(conn, ["op", "kill_monster", [this_troop_guid, this_pos, true]])
        end)

        {:halt, acc}

      _, acc ->
        {:cont, acc}
    end)

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

  def terminate(:normal, %{conn: conn, login_finish: login_finish} = _player) do
    Logger.info("avatar ternimate")
    login_finish && MsgCounter.res_onlines_sub()
    Client.tcp_close(conn)
  end

  def terminate({:shutdown, reason}, %AvatarDef{conn: conn} = player) do
    Logger.info(
      "terminate no normal, id is #{player.id}, reason is #{inspect(reason)}, data is #{inspect(player)}"
    )

    Client.tcp_close(conn)
  end

  def terminate(reason, %AvatarDef{conn: conn, login_finish: login_finish} = _player) do
    Logger.info("avatar ternimate, reason:#{reason}")
    login_finish && MsgCounter.res_onlines_sub()
    Client.tcp_close(conn)
  end

  def terminate(_, _player) do
    nil
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

  def analyze_verse(%AvatarDef{units: units, grids: grids, gid: gid}, type) do
    case map_size(units) >= 0 and type do
      :attack ->
        own_pos_list =
          grids
          |> Map.keys()
          |> Enum.flat_map(fn
            [x, y] -> [{x, y}]
            _ -> []
          end)

        total_pos = Oddr.neighbors(own_pos_list, 1, false)
        if length(total_pos) > 0, do: Enum.random(total_pos), else: nil

      :forward ->
        total_pos =
          units
          |> Enum.flat_map(fn
            {pos, %{"gid" => ^gid} = _pos_data} -> [pos]
            _ -> []
          end)

        if length(total_pos) > 0, do: Enum.random(total_pos), else: nil

      _ ->
        nil
    end
    |> case do
      [_x, _y] = pos -> pos
      {x, y} -> [x, y]
      _ -> nil
    end
  end

  def trans_params(
        params,
        %AvatarDef{
          id: aid,
          conn: conn,
          city_pos: city_pos,
          troops: troops,
          heros: heros,
          gid: gid,
          system_mails: system_mails
        } = player
      ) do
    Enum.flat_map(params, fn
      :aid ->
        [aid]

      :gid ->
        [gid]

      :ts ->
        [Utils.timestamp()]

      :ms ->
        [Utils.timestamp(:ms)]

      :rand_troop ->
        [troops |> Map.keys() |> Enum.random()]

      :troop_1 ->
        [troops |> Map.keys() |> Enum.min()]

      :troop_2 ->
        [troops |> Map.keys() |> Enum.sort(:asc) |> Enum.at(1)]

      :city_pos ->
        [city_pos]

      :rand_pos ->
        case Avatar.analyze_verse(player, :forward) do
          [_x, _y] = pos ->
            Client.send_msg(conn, ["tile_detail", pos])
            [pos]

          _ ->
            [city_pos]
        end

      :attack_pos ->
        case Avatar.analyze_verse(player, :attack) do
          [_x, _y] = pos ->
            Client.send_msg(conn, ["tile_detail", pos])
            [pos]

          _ ->
            [city_pos]
        end

      :rand_hero ->
        [heros |> Map.keys() |> Enum.random()]

      :name ->
        ["BOT#{Enum.random(1..1_000_000)}"]

      :max_mail_id ->
        [(system_mails != %{} && system_mails |> Map.keys() |> Enum.max()) || 0]

      true ->
        [true]

      false ->
        [false]

      other when is_list(other) ->
        [trans_params(other, player)]

      string when is_binary(string) ->
        trans_params([String.to_atom(string)], player)

      other when is_atom(other) ->
        ["#{other}"]

      other ->
        [other]
    end)
  end

  defp client_ip(socket) do
    case :inet.peername(socket) do
      {:ok, {client_ip, _port}} ->
        client_ip

      _ ->
        ""
    end
  end

  defp reconnect(
         %AvatarDef{
           conn: conn,
           server_ip: server_ip,
           server_port: server_port,
           id: aid,
           account: name,
           token: token,
           claim: claim,
           loop_ref: prev_ref,
           login_finish: login_finish,
           reconnect_times: r_times
         } = player
       ) do
    Client.tcp_close(conn)
    Process.put(:cmd_dic, -1)
    login_finish && MsgCounter.res_onlines_sub()

    case Client.tcp_connect(server_ip, server_port) do
      {:ok, new_conn} ->
        Client.send_msg(new_conn, ["login", name, aid, token, claim, true], false)
        is_reference(prev_ref) and Process.cancel_timer(prev_ref)
        # 等收到login再进行loop
        # new_ref = Process.send_after(self(), :loop, 1000)
        new_player = struct(player, %{conn: new_conn, login_finish: false, reconnect_times: 0})
        {:ok, new_player}

      _ ->
        {:failed, struct(player, %{conn: nil, login_finish: false, reconnect_times: r_times + 1})}
    end
  end

  defp reconnect(_), do: :error

  defp encrypt_key(token),
    do: Base.decode64!(token) |> binary_part(0, 16) |> :erlang.binary_to_list()
end
