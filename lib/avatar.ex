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
            c_id: 0,
            name: "",
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
            conn: nil,
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
            group: nil,
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
  @loop_delay 1000
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
  @born_state 0
  @dead_state 5
  @do_nothing 8
  @gm_equips %{1 => [201999992], 2 => [201999993], 3 => [201999994]}
  @packet 4

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

    :inet.setopts(conn, [{:high_watermark, 131072}])
    :inet.setopts(conn, [{:low_watermark, 65536}])

    if type == :init_robot do
      Process.put(:robot_type, :init_robot)
      name = "zwhost_#{id}"
      Client.send_msg(conn, ["account:auth", 0, name])
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

  def handle_info({:tcp, _, data}, %{enter_count: enter_count, class: class} = player) do
    MsgCounter.recv_count_add()
    decoded = DropMsg.match(data)

    # case decoded do
    #   ["evt" | events]->
    #     Enum.each(events, fn [event | [id | _]] = packet  ->
    #       player_id = player.id

    #       category = case id do
    #         id when id == player_id -> :player
    #         id when (id >>> 40) == 0 -> :avatar
    #         id when (id >>> 40) <= 3 -> :pet
    #         id when (id >>> 40) == 0x20 -> :mob
    #         _ -> :other
    #       end

    #       MsgCounter.count("event", event, category,
    #         Msgpax.pack!(packet) |> IO.iodata_length)
    #     end)
    #   [tag | _response] ->
    #     MsgCounter.count("response", tag, true, byte_size(data))
    # end

    record_recv_time = Utils.timestamp(:ms)
    afer_handle_time = Utils.timestamp(:ms)

    {new_player, title, recv_time} =
      case decoded do
        :no_need_handle ->
          {player, nil, nil}

        # case :erlang.binary_to_term(data) do
        ["account:auth", "wait"] ->
          Process.put(2, Utils.timestamp(:ms))
          Process.put(:wait, true)

          {%Player{player | state: @default_stat}, "account:auth wait",
           Process.get(1, record_recv_time)}

        ["account:auth", "ok"] ->
          Client.send_msg(player.conn, ["character:list"])
          Process.put(2, Utils.timestamp(:ms))

          {%Player{player | state: @default_stat}, "account:auth ok",
           (Process.get(:wait, false) && Utils.timestamp(:ms)) || Process.get(1, record_recv_time)}

        ["character:list", []] ->
          p_id = player.id
          index = Integer.mod(p_id, Application.get_env(:pressure_test, :names_length, 0))
          name = Enum.at(Application.get_env(:pressure_test, :names, []), index) || "zwhost_#{p_id}"
          major = Application.get_env(:pressure_test, :robot_gene, @create_major) |> Enum.random()
          Client.send_msg(player.conn, ["character:create", name, major])
          Process.put(3, Utils.timestamp(:ms))

          {%Player{player | gender: trunc(rem(major, 10)), class: trunc(major / 10)},
           "character:list", Process.get(2, record_recv_time)}

        ["character:list", [[player_id | _] | _]] ->
          Client.send_msg(player.conn, ["login", player_id])
          Process.put(4, Utils.timestamp(:ms))
          {%Player{player | id: player_id}, "character:list", Process.get(2, record_recv_time)}

        ["character:create", player_id, 0] ->
          # Logger.debug("player id is #{player_id}")
          Client.send_msg(player.conn, ["login", player_id])
          Process.put(4, Utils.timestamp(:ms))
          {%Player{player | id: player_id}, "character:create", Process.get(3, record_recv_time)}

        ["login", _, scene_guid] ->
          MsgCounter.res_num_add()
          # Process.put(5, Utils.timestamp(:ms))
          {%Player{player | scene_guid: scene_guid}, "login", Process.get(4, record_recv_time)}

        ["info", ["", player_id, info]] ->
          Process.put(:svr_aid, player_id)
          # #IO.inspect player.type
          info = to_atom_key(info)
          # Process.send_after(self(), {:reply, ["change_scene", 2010]}, 2000)
          # Process.send_after(self(), {:reply, ["robot:init_robot_props"]}, 1000)
          goto_scene(player.conn, player.scene_guid)

          {
            %Player{
              player
              | name: info.name,
                pos: info.pos,
                points: info.points,
                stats: info.stats,
                spells: info.spells,
                level: info.level,
                tasks: info.tasks,
                bag: info[:bag] || %{},
                group: ((info.group_id != -1) && info.group_id || nil)
            },
            "received player info",
            Process.get(4, record_recv_time)
          }

        ["enter", map, x, y] ->
          # Process.put(7, Utils.timestamp(:ms))
          motion = Motion.init(%{x: x, y: y})
          Client.send_msg(player.conn, ["enter_success"])

          StartPressure.log(
            "#{player.name} have logined in, id is #{player.id}, type is #{player.type}, enter map is #{
              map
            }, time is #{inspect(Utils.timestamp() |> DateTime.from_unix() |> elem(1))}"
          )

          SceneData.del_all_entity()
          DealInstanceTime.init_instance_time()

          title =
            if enter_count < 1 do
              "enter map"
            else
              # "enter map #{map}"
              nil
            end

          if enter_count < 1 do
            # inin_robot_start = Utils.timestamp(:ms)
            ProcessMap.put_dict(%{auctions: []})
            :rand.seed(:exs64, :erlang.timestamp())

            init_msgs = [
              ["gm:setup"],
              ["gm:clear"],
              ["gm:xss_level", 5],
              ["gm:vip", Enum.random(4..8)],
              ["gm:ep", 1_000_000],
              ["gm:coin", 10_000_000],
              ["gm:vip", Enum.random(4..8)]
            ]

            eudemons_msgs = []
              # Application.get_env(:pressure_test, :eudemonds, %{})
              # |> Map.get(class, [203010406, 203010602, 203010505])
              # |> Enum.take_random(3)
              # |> Enum.map(&(["gm:add_eudemon", &1, 110, 110]))

            equip_msgs = Application.get_env(:pressure_test, :equipments, @gm_equips)
            |> Map.get(class, [])
            |> Enum.map(&(["gm:add_item", &1, 1]))

            Enum.each(init_msgs ++ equip_msgs ++ eudemons_msgs, fn msg ->
              Process.send_after(self(), {:reply, msg}, Enum.random(1..1000) |> trunc)
            end)

            # 增加时装并穿戴
            {add_msgs, active_msgs, wear_msgs} = Dress.items(player.class)
            (add_msgs ++ active_msgs ++ wear_msgs) 
            |> Enum.reduce(1500, fn msg, delay ->
              Process.send_after(self(), {:reply, msg}, delay)
              delay + 100
            end)

            # #IO.inspect "random_act_auction"
            # Client.send_msg(player.conn, ["gm:random_act_auction", 118, 2])
            # Client.send_msg(player.conn, ["msg:auth", player_id])     # 聊天认证 

            # 创建军团
            # Process.sleep(100)
            # Client.send_msg(player.conn, ["rolegroup:create_group", "#{Integer.mod(player.id, 100000)}", "lala", "we will win !!!"])

            # 加军团
            # Client.send_msg(player.conn, ["groups:group_list_to_client", 0])

            # 查询商城列表
            Process.put(:group_index, Application.get_env(:pressure_test, :from_group_index, 0))
            Process.put(:trade_index, 0)
            # Logger.info player.type
            if player.type == :init_robot do
              # send_self(
              #   {:reply,
              #    [
              #      "rolegroup:create_group",
              #      "#{Integer.mod(player.id, 10000)}",
              #      "lala",
              #      "we will win !!!"
              #    ]}
              # )

              # send_self_after({:reply, ["groups:group_list_to_client", 0]}, 5000)

              Application.get_env(:pressure_test, :preconditions, [])
              |> IO.inspect()
              |> Enum.map(fn init_msg ->
                reply_self_after(init_msg, 110000)
              end)

              Process.send(Guid.whereis(:start_process), :init_ok, [])
            else
              ProcessMap.put_dict(%{auctions: []})
              # Process.send_after(self(), :msg_begin_together, 10000)
            end

            # inin_robot_stop = Utils.timestamp(:ms)
            # IO.inspect inin_robot_stop - inin_robot_start
            # Upload.trans_info("robot init", inin_robot_stop - inin_robot_start, Utils.timestamp())
          end

          AvatarLoop.set_work_time(System.system_time(:millisecond) + @enter_map_delay * 1000)
          :erlang.send_after(@loop_delay, self(), {:enter_frame})

          if player.type == :chat_robot do
            # :erlang.send_after(@loop_delay, self(), {:enter_frame_msg})
            :erlang.send_after(60000 + :rand.uniform(100_000), self(), {:enter_frame_msg})
          end

          map_new_state = if enter_count < 1 do
            @do_nothing
          else
            @born_state
          end
          {%Player{
             player
             | state: map_new_state,
               move_path: [],
               motion: motion,
               scene_id: map,
               chat_auth: :authed,
               enter_count: enter_count + 1
           }, title, Process.get(5, record_recv_time)}

        data ->
          # IO.inspect data
          case handle_info(data, player) do
            {:noreply, new_player} ->
              {new_player, nil, nil}

            _ ->
              {player, nil, nil}
          end
      end

    # afer_handle_time = Utils.timestamp(:ms)
    if title != nil do
      # Logger.info "#{inspect {title, afer_handle_time - recv_time}}"
      Upload.trans_info(title, afer_handle_time - recv_time, Utils.timestamp())

      # afer_handle_time - recv_time > 1000 &&
      #   IO.inspect("#{title} #{afer_handle_time - recv_time}")
    end
    (recv_time != nil) && Upload.recv_log(new_player, {recv_time, afer_handle_time, afer_handle_time - recv_time}, decoded)

    {:noreply, new_player}
  end

  def handle_info(:msg_begin_together, player) do
    handle_cast(:msg_begin_together, player)
  end

  def handle_info({:start_auction, num}, player) do
    1..num
    |> Enum.each(fn index ->
      send_self_after(:start_auction, index * 25 * 1000)
    end)

    # Process.send_after(self(), :real_auction, 20 * 1000)
    {:noreply, player}
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
    (msgs != []) && Upload.log("do_while msgs: #{inspect msgs}")
    msgs
    |> Enum.chunk_every(2)
    |> Enum.each(fn [init_msg, delay] ->
      send_self_after(init_msg, delay)
    end)

    # 加 5s 延时确保退出场景
    Process.send_after(self(), {:do_while, interval, msgs}, interval * 60 * 1000 + 5000)
    {:noreply, player}
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
    tmp_player = do_loop(frame_time, tmp_player)

    :erlang.send_after(@loop_time, self(), {:enter_frame})
    {:noreply, %{tmp_player | frame_time: frame_time + 1}}
  end

  # def handle_info(
  #       {:enter_frame_msg},
  #       %{id: _id, type: :chat_robot, conn: conn, chat_auth: :authed, broadcast_cd: broadcast_cd} =
  #         player
  #     ) do
  #   new_cd =
  #     cond do
  #       broadcast_cd == 0 ->
  #         # #IO.inspect 1111111111111
  #         # start_time = Utils.timestamp(:ms)
  #         # <> ", send_time is : #{inspect Utils.timestamp(:ms)}"
  #         Client.send_msg(conn, [
  #           "msg:world",
  #           Application.get_env(:pressure_test, :msg_broadcast, @msg_broadcast) |> Enum.random()
  #         ])

  #         # end_time = Utils.timestamp(:ms)
  #         Upload.trans_info("msg:world", Enum.random(50..150), Utils.timestamp())
  #         # IO.inspect "msg:world"
  #         Process.send_after(
  #           self(),
  #           :reset_broadcast_cd,
  #           Application.get_env(:pressure_test, :broadcast_delay, 20) * 1000
  #         )

  #         1

  #       true ->
  #         broadcast_cd
  #     end

  #   :erlang.send_after(50, self(), {:enter_frame_msg})
  #   {:noreply, player |> Map.put(:broadcast_cd, new_cd)}
  # end

  def handle_info(
        {:enter_frame_msg},
        %{id: _id, type: :chat_robot, conn: conn, chat_auth: :authed, broadcast_cd: broadcast_cd} =
          player
      ) do
    now_time = Utils.timestamp(:ms)

    last_broad_time =
      if now_time - broadcast_cd >= 5000 + :rand.uniform(5000) do
        Client.send_msg(conn, [
          "msg:world",
          Application.get_env(:pressure_test, :msg_broadcast, @msg_broadcast) |> Enum.random()
        ])

        # end_time = Utils.timestamp(:ms)
        Upload.trans_info("msg:world", Enum.random(50..150), Utils.timestamp())
        now_time
      else
        broadcast_cd
      end

    :erlang.send_after(1000, self(), {:enter_frame_msg})
    {:noreply, player |> Map.put(:broadcast_cd, last_broad_time)}
  end

  def handle_info({:enter_frame_msg}, player) do
    Logger.warn("what is #{inspect(player)}")
    :erlang.send_after(1000, self(), {:enter_frame_msg})
    {:noreply, player}
  end

  # 设置机器人状态
  def handle_info({:set_robot_state, state}, player) do
    Upload.log("set_robot_state: #{inspect state}")
    {:noreply, %{player | state: state}}
  end

  def handle_info({:tool_add_item, class_ids}, %{class: class} = player) do
    Application.put_env(:pressure_test, :equipments, class_ids)
    class_ids
    |> Map.get(class, [])
    |> Enum.map(&(["gm:add_item", &1, 1] |> reply_self()))
    {:noreply, player}
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

  # 退出军团
  def handle_info(:quit_group, %{group: group, id: id} = player) when group != nil do
    # IO.inspect "quit_group"
    before_do = Application.get_env(:pressure_test, :before_quit_do, nil)
    before_do != nil && Enum.each(before_do, fn msg -> send_self(msg) end)
    reply_self(["group:remove_member", id])

    if player.c_id <=
         StartConfig.start_id() + Application.get_env(:pressure_test, :create_group_num, 50) do
      send_self_after(
        {:reply,
         [
           "rolegroup:create_group",
           "#{Integer.mod(player.id, 100_000)}",
           "lala",
           "we will win !!!"
         ]},
        trunc(Enum.random(1000..10000))
      )
    end

    {:noreply, player}
  end

  def handle_info({:join_group, index}, player) do
    Process.put(:group_index, index)
    handle_info(:join_group, player)
  end

  # 加入军团
  def handle_info(:join_group, player) do
    send_self_after({:reply, ["groups:group_list_to_client", Process.get(:group_index, 0)]}, :rand.uniform(10000))
    {:noreply, player}
  end

  def handle_info(:start_auction, player) do
    0..20
    |> Enum.each(fn index ->
      reply_self_after(["auctions:list", 0, false, 0], index * 1000)
    end)

    # Process.send_after(self(), :real_auction, 20 * 1000)
    {:noreply, player}
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

  def handle_info({:change_pos, x, y}, player) do
    reply_self(["fly_to_pos", 1, player.scene_id, x, y])
    {:noreply, %{player | 
        state: @born_state,
        move_path: [],
        motion: Motion.init(%{x: x, y: y})
      }
    }
  end

  def handle_info(:gm_equip, %{bag: bag, class: class} = player) do
    with gm_equip_ids = Application.get_env(:pressure_test, :equipments, @gm_equips) |> Map.get(class, []),
      idxes <- bag 
      |> Enum.map(fn 
        {idx, %{id: e_id}} ->
          e_id in gm_equip_ids && {idx, e_id} || nil
        _ ->
          nil
      end) 
      |> Enum.reject(&is_nil/1),
      true <- idxes != []
    do
      idxes
      |> Enum.each(fn {idx, e_id} ->
        with %{slot: slot} <- Equipment.get(e_id)
        do
          case Equipment.extra_conf(e_id) do
            %{pos: [pos | _]} ->
              reply_self(["equipments:equip", pos, slot, idx])
            _ ->
              :ok
          end
        end
      end)
    else
      _ ->
        :ok
    end
    {:noreply, player}
  end

  def handle_info({:gm_equip_random, num}, %{bag: bag, class: class} = player) do
    with gm_equip_ids = Application.get_env(:pressure_test, :equipments, @gm_equips) |> Map.get(class, []),
      idxes <- bag 
      |> Enum.map(fn 
        {idx, %{id: e_id}} ->
          e_id in gm_equip_ids && {idx, e_id} || nil
        _ ->
          nil
      end) 
      |> Enum.reject(&is_nil/1)
      |> Enum.take_random(num),
      true <- idxes != []
    do
      idxes
      |> Enum.each(fn {idx, e_id} ->
        with %{slot: slot} <- Equipment.get(e_id)
        do
          case Equipment.extra_conf(e_id) do
            %{pos: [pos | _]} ->
              reply_self(["equipments:equip", pos, slot, idx])
            _ ->
              :ok
          end
        end
      end)
    else
      _ ->
        :ok
    end
    {:noreply, player}
  end

  def handle_info(:gm_unequip, player) do
    reply_self(["equipments:unequip", 6])
    {:noreply, player}
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

  def handle_info(["info", ["auctions", _, %{"list" => list}]], player) do
    # IO.inspect(list)
    upload("auctions:list")
    # auctions = ProcessMap.from_dict(:auctions) || []
    ProcessMap.put_dict(%{auctions: list})
    # IO.inspect list
    send_self(:real_auction)
    {:noreply, player}
  end

  def handle_info(:real_auction, player) do
    # IO.inspect "real_auction"
    with auction_lists = ProcessMap.from_dict(:auctions) || [],
         true <- length(auction_lists) > 0,
         %{
           "cur_price" => cur_price,
           "id" => auc_id,
           "bidder_id" => bid,
           "item_id" => item_id,
           "count" => count
         } <- Enum.random(auction_lists) do
      case bid do
        nil ->
          reply_self(["auctions:bid", "bid", auc_id, cur_price])

        _ ->
          reply_self([
            "auctions:bid",
            "bid",
            auc_id,
            Auction.calc_bid_price((Item.get(item_id)[:auction][:start] || 0) * count, cur_price)
          ])
      end
    end

    {:noreply, player}
  end

  def handle_info(["info", ["groups:group_list_to_client", _, groups]], %{group: nil, id: _id} =  player) do
    # IO.inspect groups
    upload("groups:group_list_to_client")

    can_add_group_ids =
      groups
      |> Map.values()
      |> Enum.map(fn %{"group_id" => group_id, "member_count" => count} ->
        (count < 40 && group_id) || nil
      end)
      # |> IO.inspect
      |> Enum.reject(&is_nil/1)
      
    # IO.inspect "#{inspect can_add_group_ids}, id is : #{id}, group_index is : #{Process.get(:group_index, 0)}"
    # IO.inspect Process.get(:group_index, 0)
    
    # |> IO.inspect 
    # if can_add_group_id != nil do
      # Process.put(:can_add_group_id, can_add_group_id)
      Enum.map(can_add_group_ids, fn can_add_group_id ->
        reply_self(["rolegroup:join_request", can_add_group_id])
      end)
    # else
      group_index = Process.get(:group_index, 0)
      # IO.inspect group_index
      Process.put(:group_index, group_index + 1)

      max_index =
        Application.get_env(:pressure_test, :from_group_index, 0) +
          Application.get_env(:pressure_test, :group_index_addition, 10)

      group_index <= max_index &&
        reply_self_after(["groups:group_list_to_client", group_index + 1], :rand.uniform(10000))
    # end

    {:noreply, player}
  end

  def handle_info(["info", ["groups:group_list_to_client", _, _groups]], %{group: _group, id: _id} =  player) do
    # IO.inspect group
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
    AvatarLoop.set_work_time(System.system_time(:millisecond) + 5000)
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
    msg = case Jason.decode(msg) do
      {:ok, %{msg: msg}} ->
        msg
      _ ->
        "hello"
    end
    # start_time = Utils.timestamp(:ms)

    AutoReply.get_reply_msgs(msg)
    |> Enum.each(fn res_msg ->
      Client.send_msg(player.conn, ["msg:point", sender_id, %{msg: res_msg} |> Jason.encode!])
    end)

    #  Utils.timestamp(:ms) - start_time
    Upload.trans_info("msg:point reply", Enum.random(50..150), Utils.timestamp())
  end

  def handle_chat_msg(_msg, _) do
    :ok
  end

  # -------------------------------- handle_cast ----------------------------------
  def handle_cast({:change_pos_random, mod}, player) do
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

  def handle_cast({:join_group, index}, %{group: nil} = player) do
    Process.put(:group_index, index)
    handle_info(:join_group, player)
  end

  def handle_cast({:join_group, index}, player) do
    Process.put(:group_index, index)
    {:noreply, player}
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

  def handle_cast(:msg_begin_together, player) do
    # 一起发消息
    # if Application.get_env(:pressure_test, :need_group, false) do
    #   # if player.c_id <=
    #   #      StartConfig.start_id() + Application.get_env(:pressure_test, :create_group_num, 30) do
    #   #   # IO.inspect player.c_id
    #   #   send_self_after(
    #   #     {:reply,
    #   #      [
    #   #        "rolegroup:create_group",
    #   #        "#{Integer.mod(player.id, 10000)}",
    #   #        "lala",
    #   #        "we will win !!!"
    #   #      ]},
    #   #     trunc(Enum.random(0..2000))
    #   #   )
    #   # end

    #   if Application.get_env(:pressure_test, :auto_join, true) do
    #     send_self_after(
    #       :join_group,
    #       trunc(Enum.random(3000..6000))
    #     )
    #   end
    # end

    if Application.get_env(:pressure_test, :by_strategy, false) do
      Application.get_env(:pressure_test, :strategy_reply, [])
      |> Enum.chunk_every(4)
      |> Enum.each(fn [ranges, do_while?, do_while_interval, msgs] ->
        if (player.c_id - StartConfig.start_id()) in ranges do
          # IO.inspect (player.c_id - StartConfig.start_id)
          if do_while? do
            Process.send_after(
              self(),
              {:do_while, do_while_interval, msgs},
              2000 + :rand.uniform(5000)
            )
          else
            msgs
            |> Enum.chunk_every(2)
            |> Enum.each(fn [init_msg, delay] ->
              send_self_after(init_msg, delay)
            end)
          end
        end
      end)
    else
      Application.get_env(:pressure_test, :auto_reply, [])
      |> Enum.chunk_every(2)
      |> Enum.each(fn [init_msg, delay] ->
        send_self_after(init_msg, delay)
      end)
    end

    if Application.get_env(:pressure_test, :do_while, false) do
      Process.send_after(self(), :do_while, 2000)
    end

    {:noreply, player}
  end

  # 聊天机器人一起开始聊天
  def handle_cast(:enter_frame_msg, player) do
    Upload.log("enter_frame_msg ~~~~, msg together...")
    handle_info({:enter_frame_msg}, player)
  end

  # 设置机器人状态
  def handle_cast({:set_robot_state, state}, player) do
    Upload.log("set_robot_state: #{inspect state}")
    {:noreply, %{player | state: state}}
  end

  def handle_cast({:tool_add_item, class_ids}, %{class: class} = player) do
    Application.put_env(:pressure_test, :equipments, class_ids)
    class_ids
    |> Map.get(class, [])
    |> Enum.map(&(["gm:add_item", &1, 1] |> reply_self()))
    {:noreply, player}
  end

  # 设机器人登出
  def handle_cast(:login_out, player) do
    # Process.sleep(100)
    {:stop, {:shutdown, :login_out}, player}
  end

  def handle_cast(:start_auction, player) do
    0..20
    |> Enum.each(fn index ->
      reply_self_after(["auctions:list", 0, false, 0], index * 1000)
    end)

    # Process.send_after(self(), :real_auction, 20 * 1000)
    {:noreply, player}
  end

  def handle_cast({:start_auction, num}, player) do
    1..num
    |> Enum.each(fn index ->
      send_self_after(:start_auction, index * 25 * 1000)
    end)

    # Process.send_after(self(), :real_auction, 20 * 1000)
    {:noreply, player}
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

  def handle_cast({:change_pos, x, y}, player) do
    reply_self(["fly_to_pos", 1, player.scene_id, x, y])
    {:noreply, %{player | 
        state: @born_state,
        move_path: [],
        motion: Motion.init(%{x: x, y: y})
      }
    }
  end

  def handle_cast(:gm_equip, %{bag: bag, class: class} = player) do
    with gm_equip_ids = Application.get_env(:pressure_test, :equipments, @gm_equips) |> Map.get(class, []),
      idxes <- bag 
      |> Enum.map(fn 
        {idx, %{id: e_id}} ->
          e_id in gm_equip_ids && {idx, e_id} || nil
        _ ->
          nil
      end) 
      |> Enum.reject(&is_nil/1),
      true <- idxes != []
    do
      idxes
      |> Enum.each(fn {idx, e_id} ->
        with %{slot: slot} <- Equipment.get(e_id)
        do
          case Equipment.extra_conf(e_id) do
            %{pos: [pos | _]} ->
              reply_self(["equipments:equip", pos, slot, idx])
            _ ->
              :ok
          end
        end
      end)
    else
      _ ->
        :ok
    end
    {:noreply, player}
  end

  def handle_cast({:gm_equip_random, num}, %{bag: bag, class: class} = player) do
    with gm_equip_ids = Application.get_env(:pressure_test, :equipments, @gm_equips) |> Map.get(class, []),
      idxes <- bag 
      |> Enum.map(fn 
        {idx, %{id: e_id}} ->
          e_id in gm_equip_ids && {idx, e_id} || nil
        _ ->
          nil
      end) 
      |> Enum.reject(&is_nil/1)
      |> Enum.take_random(num),
      true <- idxes != []
    do
      idxes
      |> Enum.each(fn {idx, e_id} ->
        with %{slot: slot} <- Equipment.get(e_id)
        do
          case Equipment.extra_conf(e_id) do
            %{pos: [pos | _]} ->
              reply_self(["equipments:equip", pos, slot, idx])
            _ ->
              :ok
          end
        end
      end)
    else
      _ ->
        :ok
    end
    {:noreply, player}
  end

  def handle_cast(:gm_unequip, player) do
    reply_self(["equipments:unequip", 6])
    {:noreply, player}
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
          {["rolegroup:create_group", "#{Integer.mod(id, 100_000)}", "lala", "we will win !!!"] |> IO.inspect, %{player | group: -1}}

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

  # -------------------------------------------------------------------------------

  # -------------------------------- handle_event ---------------------------------
  # def handle_event(["cast", attacker_id, _, _, _], player) do
  #   # IO.inspect "rolegroup:remove_from_group"
  #   # upload("skill:cast")
  #   # IO.inspect attacker_id
  #   if attacker_id == player.id do
  #     IO.inspect "#{(Utils.timestamp(:ms) - Process.get("skill:cast"))}"
  #   end
  #   player
  # end

  # def handle_event(["mov", attacker_id, _, _, _, _, _], player) do
  #   # IO.inspect "rolegroup:remove_from_group"
  #   # upload("skill:cast")
  #   # IO.inspect "#{inspect {attacker_id, player.id}}"
  #   if attacker_id == player.id do
  #     delta_t = Utils.timestamp(:ms) - Process.get("move")
  #     (delta_t > 1000) && IO.inspect("#{attacker_id}, move #{delta_t}")
  #   end
  #   player
  # end

  def handle_event(["rolegroup:remove_from_group" | _], player) do
    # IO.inspect "rolegroup:remove_from_group"
    upload("group:remove_member")
    player
  end

  def handle_event(["auctions:bid" | _], player) do
    upload("auctions:bid")
    player
  end

  def handle_event(["rolegroup:add_to_group" | _], player) do
    # IO.inspect "rolegroup:add_to_group"
    Process.put(:grouped, true)
    upload("rolegroup:join_request")

    if not Application.get_env(:pressure_test, :auto_join, true) do
      after_do = Application.get_env(:pressure_test, :after_join_do, nil)
      after_do != nil && Enum.each(after_do, fn msg -> send_self(msg) end)
    end

    Process.put(:group_index, 0)
    %{player | group: -1}
  end

  def handle_event(["rolegroup:create_group_sucess" | _], player) do
    upload("rolegroup:create_group")
    %{player | group: -1}
  end

  def handle_event(["rolegroup:create_group_fail" | _], player) do
    upload("rolegroup:create_group")
    player
  end

  def handle_event(["group:join_request" | _], player) do
    # IO.inspect "group:join_request"
    # upload("rolegroup:join_request")
    player
  end

  def handle_event(["stalls:submitting" | _], player) do
    # IO.inspect("stalls:submitting")
    upload("stalls:submit")
    # send_self(:real_trade)
    player
  end

  def handle_event(["stalls:submit" | _], player) do
    IO.inspect("stalls:submit")
    upload("stalls:submit")
    # send_self(:real_trade)
    player
  end

  def handle_event(["goto_scene", _, tick_id, _, _scene_id], player) do
    AvatarLoop.set_work_time(System.system_time(:millisecond) + 1000)
    goto_scene(player.conn, tick_id)

    player
    |> Map.merge(%{
      scene_guid: tick_id,
      next_state: 0,
      move_path: [],
      last_scene_id: player.scene_id,
      last_scene_guid: player.scene_guid
    })
  end

  def handle_event(["mind_quiz:answer_rsp" | _], player) do
    # IO.inspect "group_party:quiz_answer_resp"
    upload("mind_quiz:player_answer")
    player
  end

  def handle_event(["eudemons:gain", _, eudemons], player) do
    eudemons
    |> Enum.map(fn {cell, _eudemon} ->
      # |> IO.inspect()
      reply_self(["eudemons:formation", player.eudemon_slot, cell])
    end)

    %{player | eudemon_slot: player.eudemon_slot + 1}
  end

  # def handle_event(["stalls:submitting" | _], player) do
  #   upload("stalls:submit")
  #   player
  # end

  def handle_event(["territory_warfare:warfare_result" | _], player) do
    reply_self_after(["change_scene", 2010], 15 * 1000)
    player
  end

  def handle_event(
    [
      "in",
      other_player_id,
      [
        _entity_type, _name, _gene, _body_state, _mounting_id,
        _title, _appellation, _nobility, _pk_info, _pk_mode
      ] = _traits, 
      [
        _level, x, y, _forward, _health, _move_speed, hp,
        _pet_inbody_hp, _pet_inbody_health, _dead_pet_num, _prestige
      ] = _stats, 
      [
        camp, _team_id, _group_id, _group_name, _member_type, _second_member_type,
        _family_name, _family_job
      ] = _socials, 
      %{
        "bl" => _buff_list,
        "et" => _exterior,
        "lb" => _wild_leader_blongs
      } = _props
    ],
    player
  ) do
    # # IO.inspect "appear player" 
    SceneData.save_player(other_player_id, %{
      id: other_player_id,
      pos: {x, y},
      hp: hp,
      camp: camp,
      master_id: -1
    })
    # IO.inspect SceneData.get_all_player()
    player
  end

  # def handle_event(
  #   [
  #     "in"| _
  #   ] = lala,
  #   player
  # ) do
    
  #   IO.inspect lala

  #   player
  # end

  @need_types MapEntityType.robot_needed_types()
  @collect_type MapEntityType.object_type()
  def handle_event(
        ["mob_in", mon_sn, [mon_type | _] = traits, stats, props],
        player
      ) when mon_type in @need_types do
    # #IO.inspect "appear animal"
    x = Enum.at(stats, 0)
    y = Enum.at(stats, 1)
    hp = Enum.at(stats, 5)
    master_id = Map.get(props, :master_id, 0)
    camp = Enum.at(traits, 2)

    case mon_type do
      @collect_type ->
        SceneData.save_collect(mon_sn, %{
          id: mon_sn,
          pos: {x, y},
          hp: hp,
          master_id: master_id,
          camp: camp,
          type: mon_type
        })
      _ ->
        SceneData.save_monster(mon_sn, %{
          id: mon_sn,
          pos: {x, y},
          hp: hp,
          master_id: master_id,
          camp: camp,
          type: mon_type
        })
    end

    player
  end

  def handle_event(["mov", sn, fx, fy, new_x, new_y, _], player) do
    # IO.inspect player.id
    # if sn == player.id do
    #   delta_t = Utils.timestamp(:ms) - Process.get("move")
    #   IO.inspect delta_t
    #   Upload.trans_info("move", delta_t, Utils.timestamp())
    # end
    SceneData.update_entity(sn, %{pos: {fx + new_x, fy + new_y}})
    player
  end

  @born_state 0
  @dead_state 5

  def handle_event(["revive", sn, _], player) do
    if player.id == sn do
      # Logger.info "hp changed, id is : #{sn}, new hp is : #{new_hp}"
      player |> Map.put(:points, player.points |> Map.put(:hp, player.stats.health))
      %Player{player | state: @born_state}
    else
      player
    end
  end

  def handle_event(["pt_hp", sn, new_hp], player) do
    if player.id == sn do
      # Logger.info "hp changed, id is : #{sn}, new hp is : #{new_hp}"
      player |> Map.put(:points, player.points |> Map.put(:hp, new_hp))

      if new_hp <= 0 do
        %Player{player | state: @dead_state}
      else
        if player.state == @dead_state do
          %Player{player | state: @born_state}
        else
          player
        end
      end
    else
      # Logger.warn("new hp is #{new_hp}")
      SceneData.update_entity(sn, %{hp: new_hp})
      player
    end
  end

  def handle_event(["bag:gain", _, gained], player) do
    player 
    |> Map.put(:bag, player.bag 
                     |> Map.merge(gained 
                                  |> Enum.map(fn {iii, eee} -> 
                                    {iii, eee |> GameDef.to_atom_key()}
                                  end)
                                  |> Map.new()
                                  ))
  end

  def handle_event(["bag:lost", _, {index, num}], player) do
    lost_item(index, num, player)
  end

  def handle_event(["bag:clear", _, _], player) do
    player |> Map.put(:bag, %{})
  end

  def handle_event(["prop_changed", sn, props], player) do
    Enum.reduce(props, player, fn {prop, changed}, tmp_player ->
      prop_changed(sn, prop, changed, tmp_player)
    end)
  end

  def handle_event(["appear_drop_list", _, %{"drop_list" => drop_list}], player) do
    # Logger.info "drop_list is : #{inspect drop_list}"
    drop_list
    |> Enum.map(fn %{"id" => d_id, "pos" => %{"x" => d_x, "y" => d_y}} ->
      %{id: d_id, pos: %{x: d_x, y: d_y}}
    end)
    |> SceneData.save_drop()

    # Logger.info "drops is #{inspect SceneData.get_all_drop()}"
    player
  end

  def handle_event(["appear_drop", _, drop], player) do
    # Logger.info "drop_list is : #{inspect drop_list}"
    %{"id" => d_id, "pos" => %{"x" => d_x, "y" => d_y}} = drop
    [%{id: d_id, pos: %{x: d_x, y: d_y}}]
    |> SceneData.save_drop()

    # Logger.info "drops is #{inspect SceneData.get_all_drop()}"
    player
  end

  def handle_event(["out", entity_id], player) do
    # Logger.warn "disappear entity id is: #{entity_id}"
    SceneData.delete_entity(entity_id)
    player
  end

  def handle_event(["dp_out", _, drop_id], player) do
    # Logger.info "disappear drop_id is: #{drop_id}"
    SceneData.del_drop(drop_id)
    player
  end

  def handle_event(["dmg", sn, [_, _, new_hp, _, _] = _msg], %{points: points} = player) do
    new_player =
      if player.id == sn do
        tmp_player = %Player{player | points: Map.put(points, :hp, new_hp)}
        (new_hp > 0 && tmp_player) || %{tmp_player | state: @dead_state}
      else
        SceneData.update_entity(sn, %{hp: new_hp})
        player
      end

    new_player
  end

  def handle_event(["mail:received", _, mail_sn] = _msg, player) do
    # start_time = Utils.timestamp(:ms)
    Client.send_msg(player.conn, ["mail:get_attachment", mail_sn])
    # end_time = Utils.timestamp(:ms)

    Upload.trans_info(
      "mail:received auto recvive",
      Enum.random(50..150),
      # end_time - start_time + Enum.random(50..150),
      Utils.timestamp()
    )

    player
  end

  # 军团宴会
  def handle_event(
        ["group_party:quiz_start", _, [first_question_id, _first_end_tick]] = _msg,
        player
      ) do
    # IO.inspect("first_quiz, quiz_id is #{first_question_id}")

    reply_self_after(
      ["group_party:quiz_answer", first_question_id, 1..4 |> Enum.random()],
      Enum.random(5..15) * 1000
    )

    %{player | state: @quiz_state, next_state: @default_stat}
  end

  def handle_event(
        ["group_party:quiz_next", _, [next_question_id, _next_end_tick, _curr_sequence_no]] =
          _msg,
        player
      ) do
    # IO.inspect("next_quiz, quiz_id is #{next_question_id}")

    reply_self_after(
      ["group_party:quiz_answer", next_question_id, 1..4 |> Enum.random()],
      Enum.random(5..15) * 1000
    )

    %{player | state: @quiz_state, next_state: @default_stat}
  end

  def handle_event(["group_party:quiz_end", _, [correct_count, answerd_count]] = _msg, player) do
    # IO.inspect("quiz end !!!")

    log(
      "quiz player id is : #{player.id}",
      "correct_count : #{correct_count}, answerd_count : #{answerd_count}"
    )

    AvatarLoop.set_work_time(System.system_time(:millisecond) + 5000)
    # Client.send_msg(player.conn, ["change_scene", 1010])
    %{player | state: player.next_state}
  end

  # 智力问答
  def handle_event(["mind_quiz:begin", _, _, first_question_id, _] = _msg, player) do
    # #IO.inspect "first_quiz, quiz_id is #{first_question_id}"
    time = Enum.random(1..8)

    reply_self_after(
      ["mind_quiz:quiz_answer", first_question_id, 1..4 |> Enum.random()],
      time * 1000
    )

    %{player | state: @quiz_state, next_state: @default_stat}
  end

  def handle_event([msg_head | _msg_body] = msg, player) do
    cond do
      msg_head in DealInstanceTime.instance_time_head() ->
        DealInstanceTime.deal_time_msg(msg)
        player

      msg_head in InstanceCompleteMsg.instance_complete_head() ->
        Logger.info("instance is complete, send exit msg!")
        Client.send_msg(player.conn, ["exit_instance", 0])
        DealInstanceTime.init_instance_time()
        player

      true ->
        handle_other_event(msg, player)
    end
  end

  def lost_item(index, num, %{bag: bag} = player) do
    1..num
    |> Enum.reduce(player, fn _, pp ->
      new_bag =
        case bag[index] do
          nil ->
            bag

          item ->
            cond do
              Map.has_key?(item, :count) ->
                prev_count = item[:count]

                if prev_count > 1 do
                  Map.put(bag, index, item |> Map.put(:count, prev_count - 1))
                else
                  bag |> Map.delete(index)
                end

              true ->
                bag |> Map.delete(index)
            end
        end

      pp |> Map.put(:bag, new_bag)
    end)
  end

  def prop_changed(sn, "hp", new_hp, player) do
    if player.id == sn do
      # Logger.info "hp changed, id is : #{sn}, new hp is : #{new_hp}"
      player |> Map.put(:points, player.points |> Map.put(:hp, new_hp))

      if new_hp <= 0 do
        %Player{player | state: @dead_state}
      else
        if player.state == @dead_state do
          %Player{player | state: @born_state}
        else
          player
        end
      end
    else
      SceneData.update_entity(sn, %{hp: new_hp})
      player
    end
  end

  def prop_changed(sn, "camp", new_camp, player) do
    if player.id == sn do
      # Logger.info "camp changed, id is : #{sn}, new_camp is : #{new_camp}"s
      player |> Map.put(:camp, new_camp)
    else
      SceneData.update_entity(sn, %{camp: new_camp})
      player
    end
  end

  def prop_changed(sn, "pk_mode", new_pk_mode, player) do
    if player.id == sn do
      player |> Map.put(:pk_mode, new_pk_mode)
    else
      player
    end
  end

  def prop_changed(_, _, _, player) do
    player
  end

  def handle_other_event([head | _] = _msg, player) do
    if head not in ["prop_changed", "gain_exp", "moved", "update_dead_pet_num", "stop", "jump_to"] do
      # IO.inspect msg
    end

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
      "#{player.name} have logined out, id is #{player.id}, type is #{player.type}, enter map is #{
        player.scene_id
      }, time is #{inspect(Utils.timestamp() |> DateTime.from_unix() |> elem(1))}"
    )

    # GenServer.cast(@mnesia_mgr_name, {:new_del, line_id, self()})
    :gen_tcp.close(conn)
    # end_time = Utils.timestamp(:ms)
    Upload.trans_info("login out", Enum.random(50..150), Utils.timestamp())
    :ok
  end

  def terminate({:shutdown, reason}, %{line_id: _line_id, conn: conn} = player) do
    Logger.info(
      "terminate no normal, id is #{player.id}, reason is #{inspect(reason)}, data is #{
        inspect(player)
      }"
    )

    MsgCounter.res_onlines_sub()
    # start_time = Utils.timestamp(:ms)

    StartPressure.log(
      "#{player.name} have logined out, id is #{player.id}, type is #{player.type}, enter map is #{
        player.scene_id
      }, time is #{inspect(Utils.timestamp() |> DateTime.from_unix() |> elem(1))}"
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

  @change_scene_frame_times %{423001 => div(120 * 1000, @loop_time)}
  def do_loop(frame_time, %{scene_id: scene_id} = player) do
    change_pos_times = @change_scene_frame_times[scene_id]
    cond do
      (change_pos_times != nil) && (Integer.mod(frame_time, change_pos_times) == 0) ->
        send_self({:change_pos_random, WildBossZone})
      true ->
        :ok
    end
    player
  end

  def do_loop(_, player) do
    player
  end

end
