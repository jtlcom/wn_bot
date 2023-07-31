defmodule PlugRouter do
  use Plug.Router
  require Logger
  require Utils

  plug(:match)
  plug(:dispatch)

  get "/get_info" do
    data = Http.Ets.load_value(Map.get(conn, :remote_ip))
    send_resp(conn, 200, "#{inspect(data)}")
  end

  post "/save_info" do
    length =
      conn.req_headers |> Map.new() |> Map.get("content-length", "0") |> String.to_integer()

    case length > 0 && Plug.Conn.read_body(conn, length: length) do
      {:ok, body, conn} ->
        Logger.debug("/save_info body: #{inspect(body)}")

        case Jason.decode!(body) do
          %{
            "ip" => ip,
            "port" => port,
            "name_prefix" => name_prefix,
            "from" => from,
            "to" => to,
            "born_state" => born_state
          } ->
            Http.Ets.insert(conn |> Map.get(:remote_ip), %{
              ip: '#{ip}',
              port: port,
              name_prefix: name_prefix,
              from: from,
              to: to,
              born_state: born_state
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
    case Http.Ets.load_value(Map.get(conn, :remote_ip)) do
      %{ip: ip, port: port, name_prefix: name_prefix, from: from, to: to, born_state: born_state} ->
        HttpMgr.cast({:apply, StartPressure, :go, [ip, port, name_prefix, from, to, born_state]})
        send_resp(conn, 200, "ok")

      _ ->
        send_resp(conn, 200, "error")
    end
  end

  post "/gm" do
    length =
      conn.req_headers |> Map.new() |> Map.get("content-length", "0") |> String.to_integer()

    case length > 0 && Plug.Conn.read_body(conn, length: length) do
      {:ok, body, conn} ->
        Logger.debug("/gm body: #{inspect(body)}")

        case {Jason.decode!(body), Http.Ets.load_value(Map.get(conn, :remote_ip))} do
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
        Logger.debug("/forward body: #{inspect(body)}")

        case {Jason.decode!(body), Http.Ets.load_value(Map.get(conn, :remote_ip))} do
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
        Logger.debug("/attack body: #{inspect(body)}")

        case {Jason.decode!(body), Http.Ets.load_value(Map.get(conn, :remote_ip))} do
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

  post "/apply" do
    length =
      conn.req_headers |> Map.new() |> Map.get("content-length", "0") |> String.to_integer()

    case length > 0 && Plug.Conn.read_body(conn, length: length) do
      {:ok, body, conn} ->
        Logger.debug("/apply body: #{inspect(body)}")

        case {Jason.decode!(body), Http.Ets.load_value(Map.get(conn, :remote_ip))} do
          {%{"type" => type, "params" => params}, %{name_prefix: name_prefix, from: from, to: to}} ->
            Enum.each(from..to, fn this_id ->
              account = name_prefix <> "#{this_id}"
              this_pid = Avatar.Ets.load_value(account)
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

  match _ do
    send_resp(conn, 404, "Oops!")
  end
end
