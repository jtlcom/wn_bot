defmodule PlugRouter do
  use Plug.Router
  require Logger
  require Utils

  plug(:match)
  plug(:dispatch)

  get "/" do
    data =
      "total_aids: #{inspect(Avatars.number())}
onlines_count: #{inspect(MsgCounter.get_onlines_count())}"

    send_resp(conn, 200, data)
  end

  get "/help/:question" do
    res = Http.Help.get_res(question)
    send_resp(conn, 200, res)
  end

  get "/get_info" do
    http_info = Http.Ets.load_value(Map.get(conn, :remote_ip))
    send_resp(conn, 200, "#{inspect(http_info)}")
  end

  post "/save_info" do
    length =
      conn.req_headers |> Map.new() |> Map.get("content-length", "0") |> String.to_integer()

    case length > 0 && Plug.Conn.read_body(conn, length: length) do
      {:ok, body, conn} ->
        body = Jason.decode!(body)
        Logger.info("/save_info body: #{inspect(body, pretty: true)}")

        case body do
          %{
            "ip" => ip,
            "port" => port,
            "login_url" => login_url,
            "realm_http_port" => realm_http_port,
            "name_prefix" => name_prefix,
            "target_gid" => t_gid,
            "from" => from,
            "to" => to,
            "AI" => ai,
            "platform" => platform
          } ->
            Http.Ets.insert(conn |> Map.get(:remote_ip), %{
              ip: ~c"#{ip}",
              port: port,
              realm_http_port: realm_http_port,
              login_prefix: name_prefix,
              name_prefix: "#{name_prefix}_#{t_gid}_",
              from: from,
              to: to,
              AI: ai,
              platform: platform,
              login_url: login_url
            })

            send_resp(conn, 200, "ok")

          _ ->
            send_resp(conn, 200, "error")
        end

      _ ->
        send_resp(conn, 200, "error")
    end
  end

  post "/login" do
    length =
      conn.req_headers |> Map.new() |> Map.get("content-length", "0") |> String.to_integer()

    case length > 0 && Plug.Conn.read_body(conn, length: length) do
      {:ok, body, conn} ->
        body = Jason.decode!(body)
        http_info = Http.Ets.load_value(Map.get(conn, :remote_ip))

        Logger.info(
          "/login body: #{inspect(body, pretty: true)}, http_info: #{inspect(http_info, pretty: true)}"
        )

        case {body, http_info} do
          {body,
           %{
             ip: ip,
             port: port,
             login_prefix: login_prefix,
             AI: ai,
             platform: platform,
             login_url: login_url
           }} ->
            case Client.tcp_connect(ip, port) do
              {:ok, conn} ->
                Client.tcp_close(conn)

                body
                |> Enum.each(fn
                  {this_gid_name, this_nums} when is_integer(this_nums) and this_nums > 0 ->
                    try do
                      "gid_" <> this_gid = this_gid_name
                      this_gid = this_gid |> String.to_integer()
                      Logger.info("this_gid: #{this_gid}, this_nums: #{this_nums}")

                      HttpMgr.cast(
                        {:apply, StartPressure, :go,
                         [ip, port, login_prefix, this_gid, 1, this_nums, ai, platform, login_url]}
                      )
                    rescue
                      _ -> Logger.error("/login, this_gid_name: #{inspect(this_gid_name)}")
                    end

                  _ ->
                    nil
                end)

              _ ->
                Logger.warning("cannot connect #{inspect(ip)}:#{inspect(port)}")
            end

            total_nums = body |> Map.values() |> Enum.sum()
            SprAdapter.cast({:start, total_nums})

            send_resp(conn, 200, "ok")

          _ ->
            send_resp(conn, 200, "error")
        end

      _ ->
        send_resp(conn, 200, "error")
    end
  end

  post "/logout" do
    length =
      conn.req_headers |> Map.new() |> Map.get("content-length", "0") |> String.to_integer()

    case length > 0 && Plug.Conn.read_body(conn, length: length) do
      {:ok, body, conn} ->
        body = Jason.decode!(body)
        http_info = Http.Ets.load_value(Map.get(conn, :remote_ip))

        Logger.info(
          "/logout body: #{inspect(body, pretty: true)}, http_info: #{inspect(http_info, pretty: true)}"
        )

        case {body, http_info} do
          {%{}, %{name_prefix: name_prefix, from: from, to: to}} ->
            Enum.each(from..to, fn this_id ->
              account = name_prefix <> "#{this_id}"
              this_pid = Avatar.Ets.load_value(account) |> Map.get(:pid)
              Router.route(this_pid, {:logout})
            end)

            send_resp(conn, 200, "ok")

          _ ->
            send_resp(conn, 200, "error")
        end

      _ ->
        send_resp(conn, 200, "error")
    end
  end

  post "/gm" do
    length =
      conn.req_headers |> Map.new() |> Map.get("content-length", "0") |> String.to_integer()

    case length > 0 && Plug.Conn.read_body(conn, length: length) do
      {:ok, body, conn} ->
        body = Jason.decode!(body)
        http_info = Http.Ets.load_value(Map.get(conn, :remote_ip))

        Logger.debug(
          "/gm body: #{inspect(body, pretty: true)}, http_info: #{inspect(http_info, pretty: true)}"
        )

        case {body, http_info} do
          {%{"params" => params}, %{name_prefix: name_prefix, from: from, to: to}} ->
            Gm.gm(name_prefix, from, to, params)
            send_resp(conn, 200, "ok")

          _ ->
            send_resp(conn, 200, "error")
        end

      _ ->
        send_resp(conn, 200, "error")
    end
  end

  post "/forward" do
    length =
      conn.req_headers |> Map.new() |> Map.get("content-length", "0") |> String.to_integer()

    case length > 0 && Plug.Conn.read_body(conn, length: length) do
      {:ok, body, conn} ->
        body = Jason.decode!(body)
        http_info = Http.Ets.load_value(Map.get(conn, :remote_ip))

        Logger.debug(
          "/forward body: #{inspect(body, pretty: true)}, http_info: #{inspect(http_info, pretty: true)}"
        )

        case {body, http_info} do
          {%{"x" => to_x, "y" => to_y, "index" => troop_index},
           %{name_prefix: name_prefix, from: from, to: to}} ->
            Gm.forward(name_prefix, from, to, to_x, to_y, troop_index)
            send_resp(conn, 200, "ok")

          _ ->
            send_resp(conn, 200, "error")
        end

      _ ->
        send_resp(conn, 200, "error")
    end
  end

  post "/attack" do
    length =
      conn.req_headers |> Map.new() |> Map.get("content-length", "0") |> String.to_integer()

    case length > 0 && Plug.Conn.read_body(conn, length: length) do
      {:ok, body, conn} ->
        body = Jason.decode!(body)
        http_info = Http.Ets.load_value(Map.get(conn, :remote_ip))

        Logger.debug(
          "/attack body: #{inspect(body, pretty: true)}, http_info: #{inspect(http_info, pretty: true)}"
        )

        case {body, http_info} do
          {%{
             "x" => to_x,
             "y" => to_y,
             "times" => times,
             "is_back?" => is_back?,
             "index" => troop_index
           }, %{name_prefix: name_prefix, from: from, to: to}} ->
            Gm.attack(name_prefix, from, to, to_x, to_y, troop_index, times, is_back?)
            send_resp(conn, 200, "ok")

          _ ->
            send_resp(conn, 200, "error")
        end

      _ ->
        send_resp(conn, 200, "error")
    end
  end

  post "/summon" do
    length =
      conn.req_headers |> Map.new() |> Map.get("content-length", "0") |> String.to_integer()

    case length > 0 && Plug.Conn.read_body(conn, length: length) do
      {:ok, body, conn} ->
        body = Jason.decode!(body)
        http_info = Http.Ets.load_value(Map.get(conn, :remote_ip))

        Logger.debug(
          "/summon body: #{inspect(body, pretty: true)}, http_info: #{inspect(http_info, pretty: true)}"
        )

        case {body, http_info} do
          {%{
             "x" => to_x,
             "y" => to_y,
             "is_main_team" => is_main_team,
             "index" => troop_index
           }, %{name_prefix: name_prefix, from: from, to: to}} ->
            Gm.summon(name_prefix, from, to, to_x, to_y, troop_index, is_main_team)
            send_resp(conn, 200, "ok")

          _ ->
            send_resp(conn, 200, "error")
        end

      _ ->
        send_resp(conn, 200, "error")
    end
  end

  post "/stop" do
    length =
      conn.req_headers |> Map.new() |> Map.get("content-length", "0") |> String.to_integer()

    case length > 0 && Plug.Conn.read_body(conn, length: length) do
      {:ok, body, conn} ->
        body = Jason.decode!(body)
        http_info = Http.Ets.load_value(Map.get(conn, :remote_ip))

        Logger.debug(
          "/stop body: #{inspect(body, pretty: true)}, http_info: #{inspect(http_info, pretty: true)}"
        )

        case {body, http_info} do
          {%{"index" => 0}, %{name_prefix: name_prefix, from: from, to: to}} ->
            Enum.each(1..5, fn this_index ->
              Enum.each(from..to, fn this_id ->
                account = name_prefix <> "#{this_id}"
                this_pid = Avatar.Ets.load_value(account) |> Map.get(:pid)
                Router.route(this_pid, {:stop, this_index})
              end)

              Process.sleep(500)
            end)

            send_resp(conn, 200, "ok")

          {%{"index" => troop_index}, %{name_prefix: name_prefix, from: from, to: to}} ->
            Enum.each(from..to, fn this_id ->
              account = name_prefix <> "#{this_id}"
              this_pid = Avatar.Ets.load_value(account) |> Map.get(:pid)
              Router.route(this_pid, {:stop, troop_index})
            end)

            send_resp(conn, 200, "ok")

          _ ->
            send_resp(conn, 200, "error")
        end

      _ ->
        send_resp(conn, 200, "error")
    end
  end

  post "/defend" do
    length =
      conn.req_headers |> Map.new() |> Map.get("content-length", "0") |> String.to_integer()

    case length > 0 && Plug.Conn.read_body(conn, length: length) do
      {:ok, body, conn} ->
        body = Jason.decode!(body)
        http_info = Http.Ets.load_value(Map.get(conn, :remote_ip))

        Logger.debug(
          "/defend body: #{inspect(body, pretty: true)}, http_info: #{inspect(http_info, pretty: true)}"
        )

        case {body, http_info} do
          {%{"x" => to_x, "y" => to_y, "index" => 0},
           %{name_prefix: name_prefix, from: from, to: to}} ->
            Enum.each(1..5, fn this_index ->
              Enum.each(from..to, fn this_id ->
                account = name_prefix <> "#{this_id}"
                this_pid = Avatar.Ets.load_value(account) |> Map.get(:pid)
                Router.route(this_pid, {:defend, this_index, to_x, to_y})
              end)

              Process.sleep(500)
            end)

            send_resp(conn, 200, "ok")

          {%{"x" => to_x, "y" => to_y, "index" => troop_index},
           %{name_prefix: name_prefix, from: from, to: to}} ->
            Enum.each(from..to, fn this_id ->
              account = name_prefix <> "#{this_id}"
              this_pid = Avatar.Ets.load_value(account) |> Map.get(:pid)
              Router.route(this_pid, {:defend, troop_index, to_x, to_y})
            end)

            send_resp(conn, 200, "ok")

          _ ->
            send_resp(conn, 200, "error")
        end

      _ ->
        send_resp(conn, 200, "error")
    end
  end

  post "/back" do
    length =
      conn.req_headers |> Map.new() |> Map.get("content-length", "0") |> String.to_integer()

    case length > 0 && Plug.Conn.read_body(conn, length: length) do
      {:ok, body, conn} ->
        body = Jason.decode!(body)
        http_info = Http.Ets.load_value(Map.get(conn, :remote_ip))

        Logger.debug(
          "/back body: #{inspect(body, pretty: true)}, http_info: #{inspect(http_info, pretty: true)}"
        )

        case {body, http_info} do
          {%{"index" => 0}, %{name_prefix: name_prefix, from: from, to: to}} ->
            Enum.each(1..5, fn this_index ->
              Enum.each(from..to, fn this_id ->
                account = name_prefix <> "#{this_id}"
                this_pid = Avatar.Ets.load_value(account) |> Map.get(:pid)
                Router.route(this_pid, {:back, this_index})
              end)

              Process.sleep(500)
            end)

            send_resp(conn, 200, "ok")

          {%{"index" => troop_index}, %{name_prefix: name_prefix, from: from, to: to}} ->
            Enum.each(from..to, fn this_id ->
              account = name_prefix <> "#{this_id}"
              this_pid = Avatar.Ets.load_value(account) |> Map.get(:pid)
              Router.route(this_pid, {:back, troop_index})
            end)

            send_resp(conn, 200, "ok")

          _ ->
            send_resp(conn, 200, "error")
        end

      _ ->
        send_resp(conn, 200, "error")
    end
  end

  post "/faction_arena_battle" do
    length =
      conn.req_headers |> Map.new() |> Map.get("content-length", "0") |> String.to_integer()

    case length > 0 && Plug.Conn.read_body(conn, length: length) do
      {:ok, body, conn} ->
        body = Jason.decode!(body)
        http_info = Http.Ets.load_value(Map.get(conn, :remote_ip))

        Logger.debug(
          "/faction_arena_battle body: #{inspect(body, pretty: true)}, http_info: #{inspect(http_info, pretty: true)}"
        )

        case {body, http_info} do
          {%{"index" => index}, %{name_prefix: name_prefix, from: from_id, to: to_id}} ->
            Enum.each(from_id..to_id, fn this_id ->
              account = name_prefix <> "#{this_id}"
              this_pid = Avatar.Ets.load_value(account) |> Map.get(:pid)
              Router.route(this_pid, {:faction_arena_battle, index})
            end)

            send_resp(conn, 200, "ok")

          _ ->
            send_resp(conn, 200, "error")
        end

      _ ->
        send_resp(conn, 200, "error")
    end
  end

  post "/apply" do
    length =
      conn.req_headers |> Map.new() |> Map.get("content-length", "0") |> String.to_integer()

    case length > 0 && Plug.Conn.read_body(conn, length: length) do
      {:ok, body, conn} ->
        body = Jason.decode!(body)
        http_info = Http.Ets.load_value(Map.get(conn, :remote_ip))

        Logger.debug(
          "/apply body: #{inspect(body, pretty: true)}, http_info: #{inspect(http_info, pretty: true)}"
        )

        case {body, http_info} do
          {%{"type" => type, "params" => params, "interval" => interval},
           %{name_prefix: name_prefix, from: from, to: to}} ->
            Enum.each(from..to, fn this_id ->
              account = name_prefix <> "#{this_id}"

              case Avatar.Ets.load_value(account) do
                nil ->
                  :ok

                data ->
                  this_pid = data |> Map.get(:pid)
                  Router.route(this_pid, {:loop_action, type, params, interval})
              end
            end)

            send_resp(conn, 200, "ok")

          {%{"type" => type, "params" => params}, %{name_prefix: name_prefix, from: from, to: to}} ->
            Enum.each(from..to, fn this_id ->
              account = name_prefix <> "#{this_id}"

              case Avatar.Ets.load_value(account) do
                nil ->
                  :ok

                data ->
                  this_pid = data |> Map.get(:pid)
                  Router.route(this_pid, {:apply, type, params})
              end
            end)

            send_resp(conn, 200, "ok")

          _ ->
            send_resp(conn, 200, "error")
        end

      _ ->
        send_resp(conn, 200, "error")
    end
  end

  post "/multi_move_city" do
    length =
      conn.req_headers |> Map.new() |> Map.get("content-length", "0") |> String.to_integer()

    case length > 0 && Plug.Conn.read_body(conn, length: length) do
      {:ok, body, conn} ->
        body = Jason.decode!(body)
        http_info = Http.Ets.load_value(Map.get(conn, :remote_ip))

        Logger.debug(
          "/multi_move_city body: #{inspect(body, pretty: true)}, http_info: #{inspect(http_info, pretty: true)}"
        )

        case {body, http_info} do
          {%{"x" => to_x, "y" => to_y, "distance" => distance},
           %{
             ip: ip,
             realm_http_port: realm_http_port,
             name_prefix: name_prefix,
             from: from,
             to: to
           }} ->
            total_aid_list =
              Enum.flat_map(from..to, fn
                this_id ->
                  account = name_prefix <> "#{this_id}"
                  List.wrap(Avatar.Ets.load_value(account) |> Map.get(:aid))
              end)

            url = "#{ip}:#{realm_http_port}/get_move_city_pos"
            header = [{"Content-Type", "application/json"}]

            data = %{
              "x" => to_x,
              "y" => to_y,
              "aid_list" => total_aid_list,
              "distance" => distance
            }

            case HTTPoison.post(url, Jason.encode!(data), header, timeout: 3000) do
              {:ok, %{status_code: 200, body: body}} ->
                total_pos = body |> Jason.decode!()
                Logger.debug("/multi_move_city total_pos: #{inspect(total_pos)}")

                Enum.each(1..length(total_pos), fn this_index ->
                  this_pos = Enum.at(total_pos, this_index - 1)
                  this_id = Enum.at(from..to, this_index - 1)
                  account = name_prefix <> "#{this_id}"
                  this_pid = Avatar.Ets.load_value(account) |> Map.get(:pid)
                  pp = ["move_city"] ++ List.wrap(this_pos)
                  Router.route(this_pid, {:gm, pp})
                end)

                {:ok, body}

              _ ->
                nil
            end

            # Enum.each(from..to, [], fn this_id, used_pos ->
            #   Router.route(this_pid, {:apply, type, params})
            # end)

            send_resp(conn, 200, "ok")

          _ ->
            send_resp(conn, 200, "error")
        end

      _ ->
        send_resp(conn, 200, "error")
    end
  end

  post "/multi_move_born_state" do
    length =
      conn.req_headers |> Map.new() |> Map.get("content-length", "0") |> String.to_integer()

    case length > 0 && Plug.Conn.read_body(conn, length: length) do
      {:ok, body, conn} ->
        body = Jason.decode!(body)
        http_info = Http.Ets.load_value(Map.get(conn, :remote_ip))

        Logger.debug(
          "/multi_move_born_state body: #{inspect(body, pretty: true)}, http_info: #{inspect(http_info, pretty: true)}"
        )

        case {body, http_info} do
          {%{"gid" => gid}, %{name_prefix: name_prefix, from: from, to: to}} ->
            total_pos = Grid.get_city_pos(gid)

            Enum.each(from..to, fn
              this_id ->
                account = name_prefix <> "#{this_id}"
                this_pid = Avatar.Ets.load_value(account) |> Map.get(:pid)

                case Enum.at(total_pos, this_id - from) do
                  {this_x, this_y} ->
                    pp = ["move_city", this_x, this_y]
                    Router.route(this_pid, {:gm, pp})

                  _ ->
                    :ok
                end
            end)

            send_resp(conn, 200, "ok")

          _ ->
            send_resp(conn, 200, "error")
        end

      _ ->
        send_resp(conn, 200, "error")
    end
  end

  post "/build" do
    length =
      conn.req_headers |> Map.new() |> Map.get("content-length", "0") |> String.to_integer()

    case length > 0 && Plug.Conn.read_body(conn, length: length) do
      {:ok, body, conn} ->
        body = Jason.decode!(body)
        http_info = Http.Ets.load_value(Map.get(conn, :remote_ip))

        Logger.debug(
          "/build body: #{inspect(body, pretty: true)}, http_info: #{inspect(http_info, pretty: true)}"
        )

        case {body, http_info} do
          {%{"id" => build_id}, %{name_prefix: name_prefix, from: from, to: to}} ->
            Enum.each(from..to, fn this_id ->
              account = name_prefix <> "#{this_id}"
              this_pid = Avatar.Ets.load_value(account) |> Map.get(:pid)
              Router.route(this_pid, {:build, build_id})
            end)

            send_resp(conn, 200, "ok")

          _ ->
            send_resp(conn, 200, "error")
        end

      _ ->
        send_resp(conn, 200, "error")
    end
  end

  post "/kill_monster" do
    length =
      conn.req_headers |> Map.new() |> Map.get("content-length", "0") |> String.to_integer()

    case length > 0 && Plug.Conn.read_body(conn, length: length) do
      {:ok, body, conn} ->
        body = Jason.decode!(body)
        http_info = Http.Ets.load_value(Map.get(conn, :remote_ip))

        Logger.debug(
          "/kill_monster body: #{inspect(body, pretty: true)}, http_info: #{inspect(http_info, pretty: true)}"
        )

        case {body, http_info} do
          {%{}, %{name_prefix: name_prefix, from: from_id, to: to_id}} ->
            Enum.each(from_id..to_id, fn this_id ->
              account = name_prefix <> "#{this_id}"
              this_pid = Avatar.Ets.load_value(account) |> Map.get(:pid)
              Router.route(this_pid, {:kill_monster})
            end)

            send_resp(conn, 200, "ok")

          _ ->
            send_resp(conn, 200, "error")
        end

      _ ->
        send_resp(conn, 200, "error")
    end
  end

  match _ do
    send_resp(conn, 404, "Oops!")
  end
end
