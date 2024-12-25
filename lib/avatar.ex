defmodule Avatars do
  require Logger
  @name Avatar.DynamicSupervisors

  def start_child(
        {_server_ip, _server_port, account, _gid, _ai, _platform, _login_url} = args,
        opts \\ []
      ) do
    case DynamicSupervisor.start_child(
           {:via, PartitionSupervisor, {@name, Guid.name(account)}},
           {Avatar, {args, opts}}
         ) do
      {:ok, _} ->
        :ok

      error ->
        Logger.error(
          "#{__MODULE__} start_child failed, account:#{account}, args:#{inspect(args)}, error:#{inspect(error)}"
        )

        :failed
    end
  end

  def stop() do
    DynamicSupervisor.which_children(@name)
    |> Enum.each(&Supervisor.terminate_child(@name, elem(&1, 0)))
  end

  def broadcast(msg) do
    Utils.broadcast_children(@name, msg)
  end

  def pid_list(), do: CommonAPI.supervisor_childrens(@name, Avatar)
  def number(), do: pid_list() |> length
end

defmodule Avatar do
  use GenServer, restart: :transient
  require Logger
  require Utils

  def start_link({args, opts}) do
    GenServer.start_link(__MODULE__, args, opts)
  end

  def init({server_ip, server_port, name, gid, ai, platform, login_url}) do
    Logger.info(
      "account: #{inspect(name)}, ip: #{inspect(server_ip)}, pt: #{inspect(server_port)}, platform: #{platform}, login_url: #{login_url}"
    )

    Process.send_after(self(), :login, 1000)
    Process.flag(:trap_exit, true)

    {:ok,
     %AvatarDef{
       account: name,
       platform: platform,
       login_url: login_url,
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
          platform: platform,
          login_url: login_url,
          server_ip: server_ip,
          server_port: server_port,
          AI: ai
        } = player
      ) do
    begin_time = Utils.timestamp(:ms)

    case Client.login_post(name, platform, login_url) do
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

                player = struct(player, %{conn: conn, token: token, claim: claim})

                new_player =
                  if ai != 2 do
                    set_ping_loop(player)
                  else
                    player
                  end

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

                {:ok, new_player}

              _ ->
                :error3
            end

          _ ->
            :error2
        end

      {:error, error} ->
        error
    end
    |> case do
      {:ok, new_player} ->
        {:noreply, new_player}

      error ->
        Logger.warning("avatar login failed, error:#{inspect(error)}, state:#{inspect(player)}")
        Process.send_after(self(), :login, 1000)
        Process.put(:cmd_dic, -1)
        {:noreply, player}
    end
  rescue
    error ->
      Logger.warning(
        "avatar login failed, error:#{inspect(error)}, state:#{inspect(player)}, stacktrace:#{inspect(__STACKTRACE__)}"
      )

      Process.send_after(self(), :login, 1000)
      Process.put(:cmd_dic, -1)
      {:noreply, player}
  end

  def handle_info({:ping_loop, conn}, %AvatarDef{conn: conn} = player) do
    Client.send_msg(conn, ["ping", 1])
    {:noreply, set_ping_loop(player |> struct(ping_loop_ref: nil))}
  end

  def handle_info(
        {:loop, conn},
        %AvatarDef{
          id: aid,
          conn: conn,
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
    player = struct(player, %{loop_ref: nil}) |> topics_subscribe()

    new_player =
      cond do
        Process.get(:new, false) ->
          Process.put(:new, false)
          Client.send_msg(conn, ["data:get", ["heros"]])
          Client.send_msg(conn, ["gm", "god"])
          Process.sleep(500)
          Client.send_msg(conn, ["gm", "init_bot"])
          Process.sleep(500)
          Client.send_msg(conn, ["gm", "god_func"])
          set_loop(player, 1000)

        ai == 1 ->
          op_index = Process.get(:op_index, 0)

          case OpList.get(op_index) do
            {now_ms, params} when is_list(params) ->
              new_params = Avatar.trans_params(params, player)

              Logger.debug(
                "op aid:#{aid}, op_index: #{op_index}, new_params: #{inspect(new_params)}"
              )

              Client.send_msg(conn, new_params)
              Process.put(:op_index, op_index + 1)

              case OpList.get(op_index + 1) do
                {new_ms, params} when is_list(params) ->
                  set_loop(player, new_ms - now_ms)

                _ ->
                  set_loop(player) |> struct(AI: true)
              end

            _ ->
              set_loop(player) |> struct(AI: true)
          end

        ai == 2 ->
          Client.tcp_close(conn)
          player = mqtt_disconnect(player)

          case Client.tcp_connect(server_ip, server_port) do
            {:ok, conn} ->
              Client.send_msg(conn, ["login", name, aid, token, claim, true], false)
              now = Utils.timestamp()
              Process.put(:last_op_ts, now)

              player |> struct(conn: conn) |> set_loop(30000)

            _ ->
              Logger.warning("tcp_connect failed")
              player |> set_loop(1000)
          end

        ai and trunc(Utils.timestamp() - last_ts) >= 15 ->
          new_player =
            case AvatarLoop.loop(player) do
              {:ok, new_player} -> new_player
              _ -> player
            end

          now = Utils.timestamp()
          Process.put(:last_op_ts, now)
          new_player |> set_loop()

        true ->
          player |> set_loop()
      end

    {:noreply, new_player}
  rescue
    error ->
      Logger.warning(
        "loop failed, aid:#{aid}, error:#{inspect(error)}, stacktrace:#{inspect(__STACKTRACE__)}"
      )

      {:noreply, player |> set_loop()}
  end

  def handle_info(
        {:tcp, _socket, data},
        %AvatarDef{id: id, account: account, gid: gid, conn: conn} = player
      ) do
    decoded = SimpleMsgPack.unpack!(data)

    content = "recvd message------------------------------------------------:
    \t\t avatar: \t #{id}
    \t\t account: \t #{account}
    \t\t time: \t #{inspect(:calendar.local_time())}
    \t\t msg: \t #{inspect(decoded, pretty: true, limit: :infinity)}\n
    "

    AvatarLog.new_log(account, content)

    player =
      case decoded do
        ["info", ["login:choose_born_state", _id, _params]] ->
          SprReport.new_report("login:choose_born_state", player)

        _ ->
          SprReport.new_report("login", player)
      end

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
            Client.send_msg(conn, ["data:get", ["heros"]])
            Process.put(:svr_aid, new_player.id)
            Avatar.Ets.insert(account, %{pid: self(), aid: new_player.id})
            Avatar.Ets.insert(new_player.id, self())
            new_player = SprReport.send_report(new_player, "login")
            MsgCounter.res_onlines_add()
            new_player = new_player |> set_loop() |> struct(login_finish: true)
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
    Logger.info("tcp closed, socket:#{inspect(socket)}, player:#{inspect(player)}")

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
    Logger.info(
      "tcp error, socket:#{inspect(socket)}, reason:#{inspect(reason)}, player:#{inspect(player)}"
    )

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
    Logger.info("conn time out!, player:#{inspect(player)}")
    {:stop, {:shutdown, :tcp_timeout}, player}
  end

  def handle_info({:mqtt_client, _, _}, player) do
    {:noreply, player}
  end

  def handle_info(msg, player) do
    Logger.info("what msg #{inspect(msg)}, player:#{inspect(player)}")
    {:noreply, player}
  end

  def handle_call(:get_data, _from, player) do
    {:reply, player, player}
  end

  def handle_cast(:inspect_data, player) do
    Logger.info("inspect_data: #{inspect(player, pretty: true, limit: :infinity)}")
    {:noreply, player}
  end

  def handle_cast({:logout}, player) do
    {:stop, :normal, player}
  end

  def handle_cast({:atk}, player) do
    troop_guid = player |> Map.get(:troops, %{}) |> Map.keys() |> Enum.min()
    pos = analyze_verse(player, :attack)
    Client.send_msg(player.conn, ["op", "forward", [troop_guid, pos]])
    # IO.puts("atk atk atk atk atk}")
    # IO.puts("troop_guid: #{inspect(troop_guid)}}")
    # IO.puts("pos: #{inspect(pos)}}")
    {:noreply, player}
  end

  def handle_cast({:apply, type, params}, player) do
    new_params = Avatar.trans_params(List.wrap(params), player)
    Client.send_msg(player.conn, List.wrap(type) ++ new_params)
    player = SprReport.new_report(type, player)
    {:noreply, player}
  end

  def handle_cast({:forward, x, y, troop_index}, player) do
    troop_guid =
      player |> Map.get(:troops, %{}) |> Map.keys() |> Enum.sort() |> Enum.at(troop_index - 1)

    pos = [x, y]
    Client.send_msg(player.conn, ["op", "forward", [troop_guid, pos]])
    # IO.puts("troop_guid: #{inspect(troop_guid)}}")
    # IO.puts("pos: #{inspect(pos)}}")
    {:noreply, player}
  end

  def handle_cast({:attack, x, y, troop_index, times, is_back?}, player) do
    troop_guid =
      player |> Map.get(:troops, %{}) |> Map.keys() |> Enum.sort() |> Enum.at(troop_index - 1)

    pos = [x, y]
    Client.send_msg(player.conn, ["tile_detail", pos])
    Process.sleep(500)
    Client.send_msg(player.conn, ["op", "attack", [troop_guid, pos, times, is_back?]])
    player = SprReport.new_report("op", player)
    # IO.puts("troop_guid: #{inspect(troop_guid)}}")
    {:noreply, player}
  end

  def handle_cast({:summon, x, y, troop_index, is_main_team}, player) do
    troop_guid =
      player |> Map.get(:troops, %{}) |> Map.keys() |> Enum.sort() |> Enum.at(troop_index - 1)

    pos = [x, y]
    Client.send_msg(player.conn, ["op", "join_summon", [troop_guid, pos, is_main_team]])
    # IO.puts("troop_guid: #{inspect(troop_guid)}}")
    {:noreply, player}
  end

  def handle_cast({:stop, troop_index}, player) do
    troop_guid =
      player |> Map.get(:troops, %{}) |> Map.keys() |> Enum.sort() |> Enum.at(troop_index - 1)

    Client.send_msg(player.conn, ["op", "stop", [troop_guid]])
    # IO.puts("troop_guid: #{inspect(troop_guid)}}")
    {:noreply, player}
  end

  def handle_cast({:defend, troop_index, x, y}, player) do
    troop_guid =
      player |> Map.get(:troops, %{}) |> Map.keys() |> Enum.sort() |> Enum.at(troop_index - 1)

    pos = [x, y]
    Client.send_msg(player.conn, ["op", "defend", [troop_guid, pos]])
    # IO.puts("troop_guid: #{inspect(troop_guid)}}")
    {:noreply, player}
  end

  def handle_cast({:back, troop_index}, player) do
    troop_guid =
      player |> Map.get(:troops, %{}) |> Map.keys() |> Enum.sort() |> Enum.at(troop_index - 1)

    Client.send_msg(player.conn, ["op", "back", [troop_guid]])
    # IO.puts("troop_guid: #{inspect(troop_guid)}}")
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
        # IO.puts("pos: #{inspect(this_pos)}")
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
    # IO.puts("#{player.account}: params: #{inspect(params)}}")
    Client.send_msg(player.conn, ["gm"] ++ params)
    {:noreply, player}
  end

  def handle_cast({:gacha, num}, player) do
    Client.send_msg(player.conn, ["hero:gacha", 1, num])
    # IO.puts("gacha gacha gacha gacha gacha}")
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

  def terminate(:normal, %{conn: conn, login_finish: login_finish} = player) do
    Logger.info("avatar ternimate, player:#{inspect(player)}")
    login_finish && MsgCounter.res_onlines_sub()
    Client.tcp_close(conn)
  end

  def terminate({:shutdown, reason}, %AvatarDef{conn: conn} = player) do
    Logger.info("terminate shutdown, reason:#{inspect(reason)}, player:#{inspect(player)}")
    Client.tcp_close(conn)
  end

  def terminate(reason, %AvatarDef{conn: conn, login_finish: login_finish} = player) do
    Logger.info("avatar ternimate, reason:#{inspect(reason)}, player:#{inspect(player)}")
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

      :rand_aid ->
        [(aid - 5)..(aid + 5) |> Enum.random()]

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

  # defp client_ip(socket) do
  #   case :inet.peername(socket) do
  #     {:ok, {client_ip, _port}} ->
  #       client_ip

  #     _ ->
  #       ""
  #   end
  # end

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
           ping_loop_ref: ping_loop_ref,
           login_finish: login_finish,
           reconnect_times: r_times
         } = player
       ) do
    player = mqtt_disconnect(player)
    is_reference(prev_ref) and Process.cancel_timer(prev_ref)
    is_reference(ping_loop_ref) and Process.cancel_timer(ping_loop_ref)
    Client.tcp_close(conn)
    Process.put(:cmd_dic, -1)
    login_finish && MsgCounter.res_onlines_sub()

    case Client.tcp_connect(server_ip, server_port) do
      {:ok, new_conn} ->
        Client.send_msg(new_conn, ["login", name, aid, token, claim, true], false)

        new_player =
          player
          |> struct(loop_ref: nil, ping_loop_ref: nil)
          |> set_ping_loop()
          |> struct(%{conn: new_conn, login_finish: false, reconnect_times: 0})

        {:ok, new_player}

      _ ->
        {:failed, struct(player, %{conn: nil, login_finish: false, reconnect_times: r_times + 1})}
    end
  end

  defp reconnect(_), do: :error

  defp encrypt_key(token),
    do: Base.decode64!(token) |> binary_part(0, 16) |> :erlang.binary_to_list()

  defp set_loop(%AvatarDef{conn: conn, loop_ref: loop_ref} = player, interval \\ 5000) do
    is_reference(loop_ref) && Process.cancel_timer(loop_ref)
    new_ref = Process.send_after(self(), {:loop, conn}, max(interval, 10))
    struct(player, %{loop_ref: new_ref})
  end

  defp set_ping_loop(%AvatarDef{conn: conn, ping_loop_ref: ping_loop_ref} = player) do
    is_reference(ping_loop_ref) && Process.cancel_timer(ping_loop_ref)
    new_ref = Process.send_after(self(), {:ping_loop, conn}, 3000)
    struct(player, %{ping_loop_ref: new_ref})
  end

  defp mqtt_disconnect(%AvatarDef{chat_data: %{"topics" => topics} = chat_data} = data) do
    case Process.get(:mqtt_conn) do
      conn_pid when conn_pid != nil -> MQTT.Client.disconnect(conn_pid)
      _ -> :ok
    end

    if topics != %{} do
      new_chat_data = Map.put(chat_data, "topics", %{})
      data |> Map.put(:chat_data, new_chat_data)
    else
      data
    end
  end

  defp mqtt_disconnect(data) do
    data
  end

  defp mqtt_connect(%AvatarDef{
         chat_data: %{
           "port" => port,
           "ip" => ip,
           "password" => password,
           "client_id" => client_id
         }
       }) do
    opt = %{
      client_id: client_id,
      username: client_id,
      password: password,
      transport: {:tcp, %{host: ip, port: port}}
    }

    case MQTT.Client.connect(opt) do
      {:ok, conn_pid, _} ->
        Process.put(:mqtt_conn, conn_pid)
        {:ok, conn_pid}

      error ->
        Logger.warning(
          "#{__MODULE__} connect failed, error:#{inspect(error)}, opt:#{inspect(opt)}"
        )

        :failed
    end
  end

  defp mqtt_connect(_) do
    :failed
  end

  defp topics_subscribe(%AvatarDef{chat_data: %{"topics" => topics} = chat_data} = data) do
    now_time = Utils.timestamp()
    last_time = Process.put(:mqtt_last_time, now_time)

    if last_time == nil or now_time - last_time > 60 do
      case Process.get(:mqtt_conn) do
        nil ->
          mqtt_connect(data)

        conn_pid when is_pid(conn_pid) ->
          if Process.alive?(conn_pid) do
            {:ok, conn_pid}
          else
            nil
          end

        _ ->
          nil
      end
      |> case do
        {:ok, conn_pid} ->
          keys =
            topics
            |> Enum.flat_map(fn
              {k, false} -> [k]
              _ -> []
            end)

          case MQTT.Client.subscribe(conn_pid, keys) do
            {:ok, _} ->
              new_topics = topics |> Map.new(fn {k, _} -> {k, true} end)
              new_chat_data = Map.put(chat_data, "topics", new_topics)
              data |> Map.put(:chat_data, new_chat_data)

            _ ->
              data
          end

        _ ->
          data
      end
    else
      data
    end
  end

  defp topics_subscribe(data) do
    data
  end
end
