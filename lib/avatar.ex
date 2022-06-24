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
    |> Enum.each(fn {_id, pid, type, _modules} = _child ->
      (type == :worker && GenServer.cast(pid, msg)) || :ok
    end)
  end
end

defmodule Avatar.Player do
  defstruct id: 0,
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
            dynamic_units: %{},
            # --------------------
            c_id: 0,
            spells: %{},
            state: 0,
            next_state: 0,
            move_path: [],
            motion: {},
            speed: 0,
            stats: %{},
            points: %{},
            pos: %{},
            scene_guid: 0,
            scene_id: 0,
            last_scene_id: 0,
            last_scene_guid: 0,
            aimed_entity: 0,
            spells: %{},
            level: 1,
            aimed_drop_id: 0,
            camp: 0,
            pk_mode: 0,
            tasks: %{},
            line_id: 0,
            chat: nil,
            type: nil,
            chat_auth: :wait_for_auth,
            broadcast_cd: 0,
            bag: %{},
            gender: 1,
            class: 1,
            enter_count: 0,
            eudemon_slot: 0,
            trades: [],
            next_skill_time: 0,
            wetest_pid: nil,
            collect_complete: 0,
            collect_id: 0,
            frame_time: 0
end

defmodule Avatar do
  use GenServer
  require Logger
  require Utils
  # import ExchangeCode
  alias Avatar.Player

  @loop_time 150
  @loop_delay 10000
  @enter_map_delay 5
  # @server_ip Application.get_env(:pressure_test, :server_ip, '127.0.0.1')
  # @server_port Application.get_env(:pressure_test, :server_port, 8700)
  # @recv_buff Application.get_env(:pressure_test, :recv_buff, 10)
  @create_major [11, 12, 21, 22, 31, 32]
  # @mnesia_mgr_name MnesiaMgr
  @chat_msgs ["msg:auth", "msg:world", "msg:point"]

  @msg_broadcast ["*+*", "(*><*)", "^_^", "^@^", "->_->"]
  # @chat_broadcast_delay Application.get_env(:pressure_test, :broadcast_delay, 20)
  # @preconditions Application.get_env(:pressure_test, :preconditions, [])
  # @auto_reply Application.get_env(:pressure_test, :auto_reply, [])
  # @create_group_num Application.get_env(:pressure_test, :create_group_num, 30)
  # @need_group Application.get_env(:pressure_test, :need_group, false)
  # Application.get_env(:pressure_test, :default_stat, 8)
  @default_stat 8
  # @level_range Application.get_env(:pressure_test, :level_range, 60..120)
  # @by_strategy Application.get_env(:pressure_test, :by_strategy, false)
  # @strategy_reply Application.get_env(:pressure_test, :strategy_reply, [])
  # @guard_state 1
  @quiz_state 6
  @packet 2

  def start_link(args, opts \\ []) do
    GenServer.start_link(__MODULE__, args, opts)
  end

  def init({id, line_id, type}) do
    # IO.inspect id
    start_time = Utils.timestamp(:ms)
    Guid.register(self(), id)
    Process.put(:avatar_id, id)
    Process.put(:svr_aid, id)
    # {:ok, wetest_pid} = Realm.start_wetest(id)
    # Process.flag(:trap_exit, true)
    # Process.link(wetest_pid)
    [server_ip, server_port] = ServerConfig.server_ip_port()
    # Logger.info "#{server_ip}, #{server_port}"
    {:ok, conn} =
      :gen_tcp.connect(server_ip, server_port, [
        :binary,
        packet: @packet,
        active: true,
        recbuf: 1024 * 1024 * Application.get_env(:pressure_test, :recv_buff, 20),
        keepalive: true,
        nodelay: true
      ])

    :inet.setopts(conn, [{:high_watermark, 131_072}])
    :inet.setopts(conn, [{:low_watermark, 65536}])

    if type == :init_robot do
      Process.put(:robot_type, :init_robot)
      name = "zwhost_#{id}"
      Client.send_msg(conn, ["login", name])
      Process.put(1, Utils.timestamp(:ms))
      # MsgCounter.res_onlines_add()
      Process.send_after(self(), :login_out, trunc(StartConfig.leave_after() * 60 * 1000))
    else
      Process.send(Guid.whereis(:start_process), :robot_ok, [])
    end

    end_time = Utils.timestamp(:ms)
    IO.inspect(end_time - start_time)
    Upload.log("line_id: #{line_id}, robot: #{id}, init used: #{end_time - start_time}")
    # Upload.trans_info("robot #{name} login !!!", end_time - start_time, Utils.timestamp)
    {:ok, %Player{id: id, conn: conn, line_id: line_id, type: type, c_id: id}}
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

  use Bitwise

  def handle_info({:tcp, _, data}, %{id: _id} = player) do
    MsgCounter.recv_count_add()
    decoded = DropMsg.match(data)
    IO.puts("decoded: #{inspect(decoded)}")
    record_recv_time = Utils.timestamp(:ms)

    {new_player, title, recv_time} =
      case decoded do
        :no_need_handle ->
          {player, nil, nil}

        ["login", svr_data] ->
          # Realm.start_avatar 1, 1, :init_robot
          # Supervisor.which_children(Avatars)
          IO.puts("login!!!!!!!")
          new_player = player |> login_update(svr_data)
          Client.send_msg(player.conn, ["login_done"])
          :erlang.send_after(@loop_delay, self(), {:loop})

          {new_player, "login", Process.get(1, record_recv_time)}

        data ->
          # IO.inspect data
          case handle_info(data, player) do
            {:noreply, new_player} ->
              {new_player, nil, nil}

            _ ->
              {player, nil, nil}
          end
      end

    afer_handle_time = Utils.timestamp(:ms)

    if title != nil do
      Upload.trans_info(title, afer_handle_time - recv_time, Utils.timestamp())

      # afer_handle_time - recv_time > 1000 &&
      #   IO.inspect("#{title} #{afer_handle_time - recv_time}")
    end

    recv_time != nil &&
      Upload.recv_log(
        new_player,
        {recv_time, afer_handle_time, afer_handle_time - recv_time},
        decoded
      )

    {:noreply, new_player}
  end

  def handle_info(:do_while, player) do
    # IO.inspect "do_while"
    Application.get_env(:pressure_test, :while_reply, [])
    |> Enum.chunk_every(2)
    |> Enum.each(fn [init_msg, delay] ->
      send_self_after(init_msg, delay)
    end)

    do_while_interval = Application.get_env(:pressure_test, :do_while_interval, 0)

    if do_while_interval > 0 do
      # 加 5s 延时确保退出场景
      Process.send_after(self(), :do_while, trunc(do_while_interval * 60 * 1000 + 5000))
    end

    {:noreply, player}
  end

  def handle_info({:do_while, interval, msgs}, player) do
    # IO.inspect "do_while msgs"
    msgs != [] && Upload.log("do_while msgs: #{inspect(msgs)}")

    msgs
    |> Enum.chunk_every(2)
    |> Enum.each(fn [init_msg, delay] ->
      send_self_after(init_msg, delay)
    end)

    # 加 5s 延时确保退出场景
    Process.send_after(self(), {:do_while, interval, msgs}, interval * 60 * 1000 + 5000)
    {:noreply, player}
  end

  def handle_info({:loop}, %{} = player) do
    IO.puts("handle_info({:loop}  handle_info({:loop}   handle_info({:loop}")

    new_player =
      case AvatarLoop.loop(player) do
        {:ok, new_player} ->
          IO.puts("new_player new_player  new_player  new_player  new_player")
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

  def handle_info({:enter_frame}, %{frame_time: frame_time} = player) do
    # Logger.info "enter loop"
    :erlang.garbage_collect(self())
    # new_cd = cond do
    #   (type == :chat_robot) && (authed == :authed) && (broadcast_cd == 0) ->
    #     # #IO.inspect 1111111111111
    #     start_time = Utils.timestamp(:ms)
    #     Client.send_msg(conn, ["msg:world", Application.get_env(:pressure_test, :msg_broadcast, @msg_broadcast) |> Enum.random])#<> ", send_time is : #{inspect Utils.timestamp(:ms)}"
    #     end_time = Utils.timestamp(:ms)
    #     Upload.trans_info("msg:world", end_time - start_time, Utils.timestamp())
    #     # IO.inspect "msg:world"
    #     Process.send_after(self(), :reset_broadcast_cd, Application.get_env(:pressure_test, :broadcast_delay, 20) * 1000)
    #     1
    #   true ->
    #     broadcast_cd
    # end

    if DealInstanceTime.if_time_over?() do
      Logger.info("instance is end, send exit msg!")
      Client.send_msg(player.conn, ["exit_instance", 0])
      DealInstanceTime.init_instance_time()
    end

    tmp_player =
      case AvatarLoop.loop(player) do
        {:ok, new_player} ->
          new_player

        _ ->
          player
      end

    :erlang.send_after(@loop_time, self(), {:enter_frame})
    {:noreply, %{tmp_player | frame_time: frame_time + 1}}
  end

  def handle_info({:change_pos_random, mod}, player) do
    Utils.ensure_module(mod)

    if function_exported?(mod, :get_pos_random, 0) do
      try do
        {x, y} = apply(mod, :get_pos_random, [])
        send_self({:change_pos, x, y})
      rescue
        _ ->
          :ok
      end
    else
      :ok
    end

    {:noreply, player}
  end

  # 设机器人登出
  def handle_info(:login_out, player) do
    # Process.sleep(100)
    {:stop, {:shutdown, :login_out}, player}
  end

  def handle_info(:trade_all, player) do
    # IO.inspect("trade_all")
    # |> IO.inspect()
    # |> IO.inspect()
    trade_indics = player.bag |> Map.keys() |> Enum.take_random(10)

    trade_indics
    |> Enum.each(fn index ->
      reply_self_after(["stalls:submit", index, 10, 1, ""], index * 1000)
    end)

    send_self_after(:cancel_all, 20 * 1000)
    # send_self_after(:real_trade, 1000)
    {:noreply, %{player | trades: trade_indics}}
  end

  def handle_info({:trade_some, num}, player) do
    # IO.inspect "trade_some"
    trade_indics = player.bag |> Map.keys() |> Enum.take(num)
    send_self_after(:real_trade, 1000)
    {:noreply, %{player | trades: trade_indics}}
  end

  def handle_info(:real_trade, %{trades: [index | tail]} = player) do
    # IO.inspect "real_trade #{index}"
    reply_self(["stalls:submit", index, 10, 1, ""])
    {:noreply, %{player | trades: tail}}
  end

  def handle_info(:real_trade, %{trades: []} = player) do
    {:noreply, player}
  end

  def handle_info(:set_trade_query, player) do
    Process.put(:trade_query, true)
    Process.send_after(self(), :start_query, 1000)
    # IO.inspect "start_query ok !!!"
    {:noreply, player}
  end

  def handle_info(:stop_query, player) do
    Process.put(:trade_query, false)
    # IO.inspect "stop_query ok !!!"
    {:noreply, player}
  end

  @stall_query_delay 10
  def handle_info(:start_query, player) do
    reply_self(["stalls:list", 0, 0, 0, 0, [], 0, 0])

    if Process.get(:trade_query, false) do
      Process.send_after(self(), :start_query, @stall_query_delay * 1000)
    end

    # IO.inspect "trade_query ok !!!"
    {:noreply, player}
  end

  def handle_info(:reset_broadcast_cd, player) do
    {:noreply, player |> Map.put(:broadcast_cd, 0)}
  end

  def handle_info({:reply, msg}, %{conn: conn} = player) do
    # Logger.info "reply to server #{inspect msg}"
    [head | _] =
      ex_msg =
      case msg do
        ["territory_warfare:player_enter"] ->
          # |> IO.inspect()
          ["territory_warfare:player_enter", AutoEnter.get_enter_map(125, player)]

        _ ->
          msg
      end

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
        # Upload.trans_info(head, end_time - start_time, Utils.timestamp())
    end

    {:noreply, player}
  end

  def handle_info(["msg:auth", "ok"], player) do
    # #IO.inspect "msg:auth ok"
    set_channel_msg = [
      "msg:set_channels",
      %{
        "friends" => true,
        "group" => true,
        "system" => true,
        "team" => true,
        "world" => true
      }
    ]

    Client.send_msg(player.conn, set_channel_msg)
    {:onreply, player |> Map.put(:chat_auth, :authed)}
  end

  def handle_info(["msg:auth", _] = _msg, player) do
    # #IO.inspect "auth faild, recv msg : #{inspect msg}"
    {:noreply, player}
  end

  def handle_info(["info", ["group_party:quiz_answer_resp" | _]], player) do
    # IO.inspect "group_party:quiz_answer_resp"
    upload("group_party:quiz_answer")
    {:noreply, player}
  end

  @buy_num 1
  def handle_info(["info", ["shop_goods", _, goods]], player) do
    # IO.inspect "shop_goods #{player.id}  #{Utils.timestamp(:ms)}"
    upload("shop:list")

    goods
    |> Map.values()
    |> Enum.at(0)
    |> Enum.map(fn [good_id | _] ->
      Client.send_msg(player.conn, ["shop:buy", good_id, @buy_num])
      # Process.sleep(5)
    end)

    send_self_after(:trade_all, 5000)
    {:noreply, player}
  end

  # 智力问答
  def handle_info(
        ["info", ["mind_quiz:answer_reward", _id, [_, _, _, next_question_id, _, _, _]]] = _msg,
        player
      ) do
    IO.inspect("next_quiz, quiz_id is #{next_question_id}")
    time = Enum.random(1..8)

    reply_self_after(
      ["mind_quiz:player_answer", next_question_id, 1..4 |> Enum.random()],
      time * 1000 + 5000
    )

    {:noreply, %{player | state: @quiz_state, next_state: @default_stat}}
  end

  def handle_info(["info", ["mind_quiz:activity_reward", _, _]] = _msg, player) do
    # IO.inspect("quiz end !!!")

    # log("quiz player id is : #{player.id}", "correct_count : #{correct_count}, answerd_count : #{answerd_count}")
    # Client.send_msg(player.conn, ["change_scene", 1010])
    {:noreply, %{player | state: @default_stat}}
  end

  def handle_info(
        ["info", ["msg:hint", _, %{"args" => [%{"id" => act_id}], "hint" => 20_002_001}]] = _msg,
        player
      ) do
    # #IO.inspect "auto enter act : #{act_id} !!!!"
    AutoEnter.auto_enter(act_id, player)

    new_player =
      cond do
        # act_id in [118, 119] ->
        #   %{player | state: @quiz_state, next_state: @guard_state}
        true ->
          player
      end

    {:noreply, new_player}
  end

  @class_battle_leave 5
  def handle_info(["info", ["class_battle:rank_rewards" | _]] = _msg, player) do
    reply_self_after(["exit_instance", 0], @class_battle_leave * 1000)
    {:noreply, player}
  end

  # def handle_info(["info",  ["msg:hint" | _]] = msg, player) do
  #   #IO.inspect "auto enter act : #{inspect msg} !!!!"
  #   {:noreply, player}
  # end

  def handle_info([head, msg | extra_data] = _chat_msg, player) when head in @chat_msgs do
    handle_chat_msg({head, msg, extra_data}, player)
    {:noreply, player}
  end

  def handle_info(["evt" | event_msg], player) do
    player1 =
      event_msg
      |> Enum.reduce(player, fn each_event_msg, acc ->
        handle_event(each_event_msg, acc)
      end)

    {:noreply, player1}
  end

  def handle_info(_msg, player) do
    # Logger.info "what msg #{inspect msg}"
    {:noreply, player}
  end

  # -------------------------------- handle_chat_msg ------------------------------
  def handle_chat_msg({"msg:world", _msg, _}, _player) do
    # Logger.info "recv msg : #{inspect msg}"
    :ok
  end

  def handle_chat_msg({"msg:point", msg, [[sender_id | _]] = _info}, player) do
    msg =
      case Jason.decode(msg) do
        {:ok, %{msg: msg}} ->
          msg

        _ ->
          "hello"
      end

    # start_time = Utils.timestamp(:ms)

    AutoReply.get_reply_msgs(msg)
    |> Enum.each(fn res_msg ->
      Client.send_msg(player.conn, ["msg:point", sender_id, %{msg: res_msg} |> Jason.encode!()])
    end)

    #  Utils.timestamp(:ms) - start_time
    Upload.trans_info("msg:point reply", Enum.random(50..150), Utils.timestamp())
  end

  def handle_chat_msg(_msg, _) do
    :ok
  end

  # 一起开始
  def handle_cast(:begin, player) do
    name = "zwhost_#{player.id}"
    Client.send_msg(player.conn, ["account:auth", 0, name])
    Process.put(1, Utils.timestamp(:ms))
    # MsgCounter.res_onlines_add()
    Process.send_after(self(), :login_out, trunc(StartConfig.leave_after() * 60 * 1000))
    {:noreply, player}
  end

  def handle_cast({:show_data}, player) do
    IO.puts("player: #{inspect(player, pretty: true)}")
    {:noreply, player}
  end

  def handle_cast({:show_data, key}, player) do
    IO.puts("#{key}: #{inspect(Map.get(player, key), pretty: true)}")
    {:noreply, player}
  end

  def handle_cast({:atk}, player) do
    troop_guid = player |> Map.get(:troops, %{}) |> Map.keys() |> Enum.min()
    pos = analyze_verse(player, :attack)
    Client.send_msg(player.conn, ["op", "attack", [troop_guid, pos]])
    IO.puts("atk atk atk atk atk}")
    IO.puts("troop_guid: #{inspect(troop_guid)}}")
    IO.puts("pos: #{inspect(pos)}}")
    {:noreply, player}
  end

  def handle_cast({:gacha, num}, player) do
    Client.send_msg(player.conn, ["hero:gacha", 1, num])
    IO.puts("gacha gacha gacha gacha gacha}")
    {:noreply, player}
  end

  # 设机器人登出
  def handle_cast(:login_out, player) do
    # Process.sleep(100)
    {:stop, {:shutdown, :login_out}, player}
  end

  def handle_cast(:trade_all, player) do
    # IO.inspect("trade_all")
    # |> IO.inspect()
    # |> IO.inspect()
    trade_indics = player.bag |> Map.keys() |> Enum.take_random(10)

    trade_indics
    |> Enum.each(fn index ->
      reply_self_after(["stalls:submit", index, 10, 1, ""], index * 1000)
    end)

    send_self_after(:cancel_all, 20 * 1000)
    {:noreply, %{player | trades: trade_indics}}
  end

  def handle_cast(:cancel_all, player) do
    # IO.inspect("cancel_all")

    0..7
    |> Enum.each(fn index ->
      reply_self_after(["stalls:cancel", index], index * 200)
    end)

    {:noreply, player}
  end

  def handle_cast({:trade_some, num}, player) do
    # IO.inspect "trade_some"
    trade_indics = player.bag |> Map.keys() |> Enum.take(num)
    send_self_after(:real_trade, 1000)
    {:noreply, %{player | trades: trade_indics}}
  end

  def handle_cast(:set_trade_query, player) do
    Process.put(:trade_query, true)
    Process.send_after(self(), :start_query, 1000)
    # IO.inspect "start_query ok !!!"
    {:noreply, player}
  end

  def handle_cast(:stop_query, player) do
    Process.put(:trade_query, false)
    # IO.inspect "stop_query ok !!!"
    {:noreply, player}
  end

  def handle_cast({:reply, msg}, %{conn: conn, id: _id} = player) do
    # IO.inspect "#{player.id}  #{Utils.timestamp(:ms)}"
    # Logger.info("reply to server: #{inspect(msg)}")
    # start_time = Utils.timestamp(:ms)
    [head | _] =
      ex_msg =
      case msg do
        ["territory_warfare:player_enter"] ->
          # |> IO.inspect()
          ["territory_warfare:player_enter", AutoEnter.get_enter_map(125, player)]

        # ["class_battle:enter"] ->
        #   Process.put(:class_battle, true)
        #   msg

        _ ->
          msg
      end

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
        # Upload.trans_info(head, end_time - start_time, Utils.timestamp())
    end

    {:noreply, player}
  end

  def handle_cast({:reply, msg, delay}, %{conn: _conn} = player) do
    Logger.info("reply to server: #{inspect(msg)}, delay: #{delay}")
    Process.send_after(self(), {:reply, msg}, delay + :rand.uniform(5000))
    {:noreply, player}
  end

  def handle_cast(msg, %{conn: conn, id: id, type: type} = player) when type != :init_robot do
    # start_time = Utils.timestamp(:ms)

    {ex_msg, new_player} =
      case msg do
        ["rolegroup:create_group"] ->
          {["rolegroup:create_group", "#{Integer.mod(id, 100_000)}", "lala", "we will win !!!"]
           |> IO.inspect(), %{player | group: -1}}

        _ ->
          {msg, player}
      end

    Logger.info("#{inspect(ex_msg)}")
    Client.send_msg(conn, ex_msg)
    # end_time = Utils.timestamp(:ms)
    Upload.trans_info(Enum.at(ex_msg, 0), Enum.random(50..150), Utils.timestamp())
    {:noreply, new_player}
  end

  def handle_cast(_msg, player) do
    {:noreply, player}
  end

  # -------------------------------- handle_event ---------------------------------
  def handle_event(["prop_changed", _id, changed], player) do
    IO.puts("new prop_changed  new new new !")
    upload("prop_changed")
    player |> changed_update(changed)
  end

  def handle_event(["units", _, units_data], player) do
    IO.puts("new units  new new new !")
    upload("units")
    player |> verse_update(:units, units_data)
  end

  def handle_event(other, player) do
    [head | _] = other
    IO.puts("other_head : #{inspect(head, pretty: true)} !")
    player
  end

  def log(msg, data) do
    File.write("quiz.txt", "#{inspect(msg)}\n#{inspect(data)}\n\n", [:append])
  end

  # -------------------------------------------------------------------------------

  def terminate(:normal, %{line_id: _line_id, conn: conn} = player) do
    Logger.info("avatar ternimate")
    MsgCounter.res_onlines_sub()
    # start_time = Utils.timestamp(:ms)

    StartPressure.log(
      "#{player.name} have logined out, id is #{player.id}, type is #{player.type}, enter map is #{player.scene_id}, time is #{inspect(Utils.timestamp() |> DateTime.from_unix() |> elem(1))}"
    )

    # GenServer.cast(@mnesia_mgr_name, {:new_del, line_id, self()})
    :gen_tcp.close(conn)
    # end_time = Utils.timestamp(:ms)
    Upload.trans_info("login out", Enum.random(50..150), Utils.timestamp())
    :ok
  end

  def terminate({:shutdown, reason}, %{line_id: _line_id, conn: conn} = player) do
    Logger.info(
      "terminate no normal, id is #{player.id}, reason is #{inspect(reason)}, data is #{inspect(player)}"
    )

    MsgCounter.res_onlines_sub()
    # start_time = Utils.timestamp(:ms)

    StartPressure.log(
      "#{player.name} have logined out, id is #{player.id}, type is #{player.type}, enter map is #{player.scene_id}, time is #{inspect(Utils.timestamp() |> DateTime.from_unix() |> elem(1))}"
    )

    # GenServer.cast(@mnesia_mgr_name, {:new_del, line_id, self()})
    :gen_tcp.close(conn)
    # end_time = Utils.timestamp(:ms)
    Upload.trans_info("login out", Enum.random(50..150), Utils.timestamp())
    :ok
  end

  def terminate(_, _player) do
    MsgCounter.res_onlines_sub()
    :ok
  end

  defp reply_self(msg) do
    Process.send(self(), {:reply, msg}, [])
  end

  defp reply_self_after(msg, delay) do
    Process.send_after(self(), {:reply, msg}, delay + :rand.uniform(5000))
  end

  defp send_self(msg) do
    Process.send(self(), msg, [])
  end

  defp send_self_after(msg, delay) do
    Process.send_after(self(), msg, delay + :rand.uniform(5000))
  end

  def upload(title) do
    recv_time = Process.get(title, Utils.timestamp(:ms))
    # Process.sleep(50)
    Upload.trans_info(title, Utils.timestamp(:ms) - recv_time, Utils.timestamp())
  end

  def goto_scene(conn, guid) do
    # Logger.info "conn is #{inspect player.conn}, guid is #{guid}"
    Client.send_msg(conn, ["enter", guid])
    Process.put(5, Utils.timestamp(:ms))
  end

  def to_atom_key(config) when is_map(config) do
    config
    |> Map.new(fn {k, v} ->
      {parse_key_to_atom(k), to_atom_key(v)}
    end)
  end

  def to_atom_key(config) when is_list(config) do
    Enum.map(config, fn ss -> to_atom_key(ss) end)
  end

  def to_atom_key(config) do
    config
  end

  defp parse_key_to_atom(key) when is_binary(key) do
    case Integer.parse(key) do
      {k1, _} ->
        k1

      _ ->
        Utils.to_atom(key)
    end
  end

  defp parse_key_to_atom(key) do
    key
  end

  def int_key_to_string(config) when is_map(config) do
    config
    |> Map.new(fn {k, v} ->
      if is_integer(k) do
        {Integer.to_string(k), int_key_to_string(v)}
      else
        {to_string(k), int_key_to_string(v)}
      end
    end)
  end

  def int_key_to_string(config) do
    config
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

    %Player{
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

  def changed_update(player, changed) do
    Enum.reduce(changed, player, fn
      {key, data}, player_acc when is_binary(key) ->
        key = key |> String.to_atom()
        if Map.has_key?(player_acc, key), do: Map.put(player_acc, key, data), else: player_acc

      {key, data}, player_acc when is_atom(key) ->
        if Map.has_key?(player_acc, key), do: Map.put(player_acc, key, data), else: player_acc

      _, player_acc ->
        player_acc
    end)
  end

  def verse_update(player, type, verse_data) do
    case type do
      :units -> player |> Map.put(:units, Map.merge(player.units, verse_data))
      :fixed_units -> player |> Map.put(:fixed_units, Map.merge(player.fixed_units, verse_data))
      _ -> player
    end
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
end
