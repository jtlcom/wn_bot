defmodule PlugRouter do
  use Plug.Router
  require Logger
  require Utils

  plug(:match)
  plug(:dispatch)

  get "/" do
    data = "
onlines_count: #{inspect(MsgCounter.get_onlines_count())}\n
dead_count: #{inspect(MsgCounter.get_dead_count())}"
    send_resp(conn, 200, data)
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
            "name_prefix" => name_prefix,
            "from" => from,
            "to" => to,
            "AI" => ai
          } ->
            Http.Ets.insert(conn |> Map.get(:remote_ip), %{
              ip: '#{ip}',
              port: port,
              name_prefix: name_prefix,
              from: from,
              to: to,
              AI: ai
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
          {%{"born_state" => born_state},
           %{ip: ip, port: port, name_prefix: name_prefix, from: from, to: to, AI: ai}} ->
            HttpMgr.cast(
              {:apply, StartPressure, :go, [ip, port, name_prefix, from, to, born_state, ai]}
            )

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
          {%{"type" => type, "params" => params}, %{name_prefix: name_prefix, from: from, to: to}} ->
            Enum.each(from..to, fn this_id ->
              account = name_prefix <> "#{this_id}"
              this_pid = Avatar.Ets.load_value(account) |> Map.get(:pid)
              Router.route(this_pid, {:apply, type, params})
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
           %{ip: ip, name_prefix: name_prefix, from: from, to: to}} ->
            total_aid_list =
              Enum.flat_map(from..to, fn
                this_id ->
                  account = name_prefix <> "#{this_id}"
                  List.wrap(Avatar.Ets.load_value(account) |> Map.get(:aid))
              end)

            url = "#{ip}:#{20003}/get_move_city_pos"
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

  match _ do
    send_resp(conn, 404, "Oops!")
  end
end
