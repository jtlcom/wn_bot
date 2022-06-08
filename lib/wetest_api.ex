defmodule WeTestApi.Supervisor do
  use Supervisor
  @name WeTestApis

  def start_link() do
    Supervisor.start_link(__MODULE__, [], name: @name)
  end

  def start_child(args, opts \\ []) do
    Supervisor.start_child(@name, [args, opts])
  end

  def init(_) do
    children = [
      worker(WeTestApi, [], restart: :transient)
    ]
    supervise(children, strategy: :simple_one_for_one)
  end

end

defmodule WeTestApi do
  use GenServer
  require Utils
  require Logger

  # @apiurl Application.get_env(:pressure_test, :wetest_api) |> Map.get(:apiurl)
  # @secretid Application.get_env(:pressure_test, :wetest_api) |> Map.get(:secretid)
  # @secretkey Application.get_env(:pressure_test, :wetest_api) |> Map.get(:secretkey)
  # @projectid Application.get_env(:pressure_test, :wetest_api) |> Map.get(:projectid)
  @expiretime 0
  @tab :wetest_api
  @key :host_url
  @headers [{"Content-Type", "application/json"}, {"Connection", "keep-alive"}]
  # @zoneid Application.get_env(:pressure_test, :wetest_api) |> Map.get(:zoneid)
  @try_time :force
  @loop_interval 1000
  @statistics_name :lala

  def start_link(args, opts \\ []) do
    GenServer.start_link(__MODULE__, args, opts)
  end

  def init({:child, index}) do
    Guid.register(self(), Guid.new(:wetest, index))
    Process.send_after(self(), :enter_frame, 10)
    {:ok, {get_state_wetest(), []}}
  end

  def init() do
    :ok = :hackney_pool.start_pool(:first_pool, [timeout: 15000, max_connections: 100])
    HTTPoison.start()
    state = testid_instanceid_dcAddr(Application.get_env(:pressure_test, :wetest_api_false, @try_time))
    :ets.insert(@tab, {:wetest_state, state})
    # {:ok, state}
    # {:ok, %{state: :wait_init}}
  end

  # def handle_info(:start_test, %{state: :wait_init} = state) do
  #   {:noreply, testid_instanceid_dcAddr(@try_time)}
  # end

  # def handle_info(:start_test, %{state: :inited} = state) do
  #   stop_test(Application.get_env(:pressure_test, :wetest_api) |> Map.get(:projectid), state[:testid], state[:instanceid]) 
  #   {:noreply, testid_instanceid_dcAddr(@try_time)}
  # end

  def handle_cast(:register_load, {%{state: :inited}, _} = state) do
    Logger.info("register_load !!!")
    register_load()
    {:noreply, state}
  end

  def handle_cast({:trans_info, {title, _, _} = transParamsStr}, {%{state: :inited} = ss, trans_info_array} = _state) do
    # IO.inspect transParamsStr
    # Logger.info "trans_info: #{inspect transParamsStr}"
    SimpleStatistics.insert_events(transParamsStr)
    key = title |> String.replace(" ", "_") |> String.to_atom
    statictis_proto(key)
    {:noreply, {ss, [transParamsStr | trans_info_array]}}
  end

  def handle_cast({:trans_info, transParamsStr}, state) do
    # Logger.info "trans_info: #{inspect transParamsStr}"
    # IO.inspect transParamsStr
    SimpleStatistics.insert_events(transParamsStr)
    {:noreply, state}
  end

  def handle_cast({:statistics_info, transParamsStr}, {%{state: :inited}, _} = state) do
    # Logger.info "statistics_info: #{inspect transParamsStr}"
    statistics_info(transParamsStr)
    # SimpleStatistics.update_onlies(transParamsStr[:data][:robot_online_num] || 0)
    {:noreply, state}
  end

  def handle_cast({:statistics_info, _transParamsStr}, state) do
    # SimpleStatistics.update_onlies(transParamsStr[:data][:robot_online_num] || 0)
    {:noreply, state}
  end

  def handle_cast(:stop_test, {%{state: :inited}, _} = state) do
    Logger.info "stop test : #{inspect state}"
    stop_test()
    {:noreply, {%{state: :wait_init}, []}}
  end

  def handle_cast(_, state) do
    {:noreply, state}
  end

  def handle_info(:enter_frame, {%{state: :inited} = ss, arrays} = _state) do
    # :erlang.garbage_collect(self())
    # IO.inspect "lala"
    if not local_wetest?() do
      cond do
        arrays == [] ->
          :ok
        true ->
          ex_arrays = arrays |> Enum.map(fn {title, time_cost, timestamp} ->
            if time_cost >= 3000 do
              Logger.info "#{inspect title} cost #{time_cost}"
            end
            %{
              trans_name: title, 
              time_cost: time_cost, 
              trans_result: 1,
              timestamps: timestamp
            } 
          end)
          # Logger.info "#{inspect ex_arrays}"
          trans_info(%{data: ex_arrays})
      end
    end
    # IO.inspect Utils.timestamp()
    Process.send_after(self(), :enter_frame, @loop_interval)
    {:noreply, {ss, []}}
  end

  def handle_info(:close, state) do
    stop_test()
    {:noreply, state}
  end

  def handle_info(_, state) do
    {:noreply, state}
  end

  def terminate(_, {%{state: :inited}, _} = state) do
    Logger.info("stop test : #{inspect(state)}")
  end

  def terminate(_, _state) do
    stop_test()
    :ok
  end

  defp statictis_proto(type) do
    if :ets.lookup(@statistics_name, type) == [] do
      :ets.insert(@statistics_name, {type, 0})
    end
    :ets.update_counter(@statistics_name, type, 1)
  end

  def get_state_wetest() do
    Keyword.get(:ets.lookup(@tab, :wetest_state), :wetest_state)
  end

  def get_signature_params(path, params, method) do
    data =
      %{
        timestamp: Utils.timestamp(),
        nonce: :random.uniform(9999),
        signaturemethod: "HmacSHA256",
        expire: @expiretime,
        secretid: Application.get_env(:pressure_test, :wetest_api) |> Map.get(:secretid)
      }
      |> Map.merge(params)

    source_str =
      Enum.reduce(data, method <> path <> "?", fn {k, v}, acc ->
        acc <> "#{k}=#{v}&"
      end)
      |> String.trim("&")

    # |> #IO.inspect
    signature =
      :crypto.hmac(
        :sha256,
        "#{Application.get_env(:pressure_test, :wetest_api) |> Map.get(:secretkey)}",
        source_str
      )
      |> Base.encode64()

    {data, signature}
  end

  def get_request_uri(path) do
    # #IO.inspect Keyword.get(:ets.lookup(@tab, @key), @key)
    Keyword.get(:ets.lookup(@tab, @key), @key) <> path
  end

  def start_test() do
    path = "/gapsapi/data_collect_v1/start_test"

    params = %{
      projectid: Application.get_env(:pressure_test, :wetest_api) |> Map.get(:projectid),
      zoneid: Application.get_env(:pressure_test, :wetest_api) |> Map.get(:zoneid)
    }

    get_response_by_get(path, params)
  end

  def stop_test(try_time \\ 3) do
    wetest_state = get_state_wetest()
    set_host(Application.get_env(:pressure_test, :wetest_api) |> Map.get(:apiurl))
    path = "/gapsapi/data_collect_v1/stop_test"

    params = %{
      testid: wetest_state[:testid],
      projectid: Application.get_env(:pressure_test, :wetest_api) |> Map.get(:projectid),
      # instid
      instid: -1
    }

    response = get_response_by_get(path, params)
    Logger.info("the #{try_time}th time stop_test get response : #{inspect(response)}")

    if response[:ret] != nil && response[:ret] != 0 && try_time > 0 do
      stop_test(try_time - 1)
    else
      response
    end
  end

  def register_load() do
    path = "/gapsapi/data_collect_v1/register_load"
    wetest_state = get_state_wetest()

    params = %{
      testid: wetest_state[:testid],
      projectid: Application.get_env(:pressure_test, :wetest_api) |> Map.get(:projectid),
      instanceid: wetest_state[:instanceid]
    }

    get_response_by_get(path, params)
  end

  def trans_info(transParamsStr \\ %{}) do
    path = "/gapsapi/data_collect_v1/trans_info"
    wetest_state = get_state_wetest()

    params = %{
      testid: wetest_state[:testid],
      projectid: Application.get_env(:pressure_test, :wetest_api) |> Map.get(:projectid),
      instanceid: wetest_state[:instanceid]
    }

    # transParamsStr = %{data: [
    #   %{
    #       trans_name: "login", 
    #       time_cost: 1000, 
    #       trans_result: 1
    #     }
    #   ]
    # } 
    # Logger.info("trans_info #{inspect(transParamsStr)}")
    get_response_by_post(path, params, transParamsStr)
  end

  def statistics_info(transParamsStr \\ %{}) do
    path = "/gapsapi/data_collect_v1/statistics_info"
    wetest_state = get_state_wetest()

    params = %{
      testid: wetest_state[:testid],
      projectid: Application.get_env(:pressure_test, :wetest_api) |> Map.get(:projectid),
      instanceid: wetest_state[:instanceid]
    }

    # transParamsStr = %{data:
    #   %{
    #     recv_pkg_total_num: 10, 
    #     send_pkg_total_num: 10, 
    #     robot_total_num: 1, 
    #     robot_online_num: 1 
    #   }
    # }
    # Logger.info "statistics_info #{inspect transParamsStr}"
    get_response_by_post(path, params, transParamsStr)

    # Upload.log("#{inspect({transParamsStr[:data][:robot_online_num], transParamsStr[:data][:robot_total_num]})}")
  end

  def set_host(url) do
    :ets.insert(@tab, {@key, url})
  end

  defp urlencode({params, signature}) do
    tmp_url =
      params
      |> Enum.reduce("", fn {k, v}, acc ->
        acc <> "#{k}=#{v}&"
      end)

    tmp_url <> "signature=#{signature}"
  end

  defp get_response_by_get(path, params) do
    get_response_by_get(path, params, 1)
  end

  defp get_response_by_get(_path, _params, 0) do
    %{}
  end

  defp get_response_by_get(path, params, time) do
    if not local_wetest?() do
      options = [ssl: [{:versions, [:"tlsv1.2"]}], recv_timeout: 5000, hackney: [pool: :first_pool]]
      # |> #IO.inspect
      response =
        (get_request_uri(path) <> "?" <> urlencode(get_signature_params(path, params, "GET")))
        |> HTTPoison.get([], options)
        |> elem(1)

      result = response |> Map.take([:body, :status_code])
      Logger.info("#{inspect(result)}")

      case result do
        %{status_code: 200, body: body} ->
          # IO.inspect body
          case Jason.decode(body) do
            {:ok, data} when is_map(data) ->
              data |> to_atom_key()

            _ ->
              %{}
          end

        _ ->
          Logger.info("response is #{inspect(response)}")
          get_response_by_get(path, params, time - 1)
      end
    else
      %{}
    end
    # (result[:status_code] == 200) && (Poison.decode!(result[:body] || %{}) |> to_atom_key()) || %{}
  end

  # defp get_response_by_get_1(path, params) do
  #   url =
  #     (get_request_uri(path) <> "?" <> urlencode(get_signature_params(path, params, "GET")))
  #     |> String.to_charlist()

  #   case :httpc.request(url) do
  #     {:ok, {_, _, result}} ->
  #       {:ok, result1} = Jason.decode(result)
  #       result1 = to_atom_key(result1)
  #       Logger.debug("result is #{inspect(result)}, result1 is #{inspect(result1)}")
  #       result1

  #     what ->
  #       Logger.info("get what is #{inspect(what)}")
  #       %{}
  #   end
  # end

  defp get_response_by_post(path, params, transParamsStr) do
    get_response_by_post(path, params, transParamsStr, 1)
  end

  defp get_response_by_post(_path, _params, _transParamsStr, 0) do
    %{}
  end

  defp get_response_by_post(path, params, transParamsStr, time) do
    if not local_wetest?() do
      options = [ssl: [{:versions, [:"tlsv1.2"]}], recv_timeout: 500, hackney: [pool: :first_pool]]
      response =
        (get_request_uri(path) <> "?" <> urlencode(get_signature_params(path, params, "POST")))
        |> HTTPoison.post(transParamsStr |> Jason.encode!(), @headers, options)
        |> elem(1)
      result = response |> Map.take([:body, :status_code])
      case result do
        %{status_code: 200, body: body} ->
          # IO.inspect body
          case Jason.decode(body) do
            {:ok, data} when is_map(data) ->
              data |> to_atom_key()
            _ ->
              %{}
          end
        _ ->
          Logger.info("result is #{inspect(response)}")
          get_response_by_post(path, params, transParamsStr, time - 1)
      end
    else
      %{}
    end
    # (result[:status_code] == 200) && (Poison.decode!(result[:body] || %{}) |> to_atom_key()) || %{}
  end

  # defp get_response_by_post_1(path, params, transParamsStr, _time \\ 2) do
  #   url =
  #     (get_request_uri(path) <> "?" <> urlencode(get_signature_params(path, params, "POST")))
  #     |> String.to_charlist()

  #   content_type = "application/x-www-form-urlencoded" |> String.to_charlist()
  #   content = transParamsStr |> Jason.encode!() |> String.to_charlist()

  #   case :httpc.request(:post, {url, '', content_type, content}, [timeout: 4000], []) do
  #     {:ok, {_, _headers1, body_rec}} ->
  #       body_rec1 = Jason.decode(to_string(body_rec))
  #       Logger.info("body is #{inspect(body_rec1)}")

  #       case body_rec1 do
  #         {_, result_list} when is_map(result_list) ->
  #           result_list
  #           |> to_atom_key

  #         _ ->
  #           %{}
  #       end

  #     _ ->
  #       %{}
  #   end
  # end

  def to_atom_key(config) when is_map(config) do
    config |> Map.new(fn {k, v} -> {Utils.to_atom(k), to_atom_key(v)} end)
  end

  def to_atom_key(config) do
    config
  end

  def test_api() do
    set_host(Application.get_env(:pressure_test, :wetest_api) |> Map.get(:apiurl))
    # |> #IO.inspect
    startRst = start_test()
    testid = startRst[:testid]
    # instanceid = startRst[:instanceid]
    dcAddr = startRst[:dcAddr]

    with true <- testid != nil,
         true <- dcAddr != nil do
      # authparams = %{
      #   secretid: Application.get_env(:pressure_test, :wetest_api) |> Map.get(:secretid),
      #   secretkey: Application.get_env(:pressure_test, :wetest_api) |> Map.get(:secretkey),
      # }
      set_host("http://" <> dcAddr)
      # |> #IO.inspect
      register_load()

      Enum.each(1..10, fn _ii ->
        transParamsStr = %{
          data: [
            %{
              trans_name: "login",
              time_cost: 1000,
              trans_result: 1
            }
          ]
        }

        # |> #IO.inspect
        trans_info(transParamsStr)

        transParamsStr = %{
          data: %{
            recv_pkg_total_num: 10,
            send_pkg_total_num: 10,
            robot_total_num: 1,
            robot_online_num: 1
          }
        }

        # |> #IO.inspect
        statistics_info(transParamsStr)
      end)

      # |> #IO.inspect
      stop_test()
    else
      _ ->
        Logger.info("get testid failed")
    end
  end

  def testid_instanceid_dcAddr(:force) do
    %{state: :inited}
  end

  def testid_instanceid_dcAddr(0) do
    %{state: :wait_init}
  end

  def testid_instanceid_dcAddr(try_time) do
    set_host(Application.get_env(:pressure_test, :wetest_api) |> Map.get(:apiurl))
    startRst = start_test() |> IO.inspect()
    testid = startRst[:testid]
    instanceid = startRst[:instanceid]
    dcAddr = startRst[:dcAddr]

    with true <- testid != nil,
         true <- dcAddr != nil do
      tt_addr = "http://" <> dcAddr
      set_host(tt_addr)
      state = %{testid: testid, instanceid: instanceid, addr: tt_addr, state: :inited}
      log("try time #{try_time}, get testid successful !!!", state)
      state
    else
      _ ->
        testid_instanceid_dcAddr(try_time - 1)
    end
  end

  def log(msg, data) do
    File.write(
      "WeTestApi_log.txt",
      "#{inspect(Utils.timestamp() |> DateTime.from_unix() |> elem(1))} ---- #{inspect(msg)}\n#{
        inspect(data)
      }\n\n",
      [:append]
    )
  end

  # defp map_to_json(%{data: [
  #     %{
  #         trans_name: "login", 
  #         time_cost: 1000, 
  #         trans_result: 1
  #       }
  #     ]
  #   } ) do

  # end

  def local_wetest?() do
    Application.get_env(:pressure_test, :wetest_api_false, @try_time) == :force
  end

end
