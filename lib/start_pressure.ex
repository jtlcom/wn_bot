defmodule StartPressure do
  require Logger

  def go(server_ip, server_port, name_prefix, from, to, born_state) do
    # StartPressure.go('192.168.1.129', 6666, "bot_1_", 1, 2, 1)
    start_some(server_ip, server_port, name_prefix, from, to, born_state)
  end

  def start_single(server_ip, server_port, name_prefix, id, born_state) do
    account = name_prefix <> "#{id}"

    case HTTPoison.post(
           "http://192.168.1.92:8080/auth/whynot",
           %{"account" => account, "password" => "111111"} |> URI.encode_query(),
           [{"Content-Type", "application/x-www-form-urlencoded"}],
           timeout: 5000
         ) do
      {:ok, %{body: body}} ->
        case Jason.decode!(body) do
          %{"login_with_data" => login_with_data, "token" => token} ->
            case Avatar.Supervisor.start_child(
                   {server_ip, server_port, account, born_state, token, login_with_data},
                   name: {:global, {:name, Guid.name(id)}}
                 ) do
              {:ok, pid} ->
                pid

              _ ->
                nil
            end

          _ ->
            :error
        end

      {:error, _error} ->
        :error
    end
  end

  def start_some(server_ip, server_port, name_prefix, from_id, to_id, born_state) do
    try_one =
      :gen_tcp.connect(server_ip, server_port, [
        :binary,
        packet: Avatar.packet(),
        active: true,
        recbuf: 1024 * 1024 * Application.get_env(:whynot_bot, :recv_buff, 20),
        keepalive: true,
        nodelay: true
      ])

    case try_one do
      {:ok, conn} ->
        :gen_tcp.close(conn)
        strategy(:once_time, server_ip, server_port, name_prefix, from_id, to_id, born_state)

      _ ->
        Logger.info("cannot connect #{inspect(server_ip)}:#{inspect(server_port)}")
    end
  end

  def strategy(:once_time, server_ip, server_port, name_prefix, from_id, to_id, born_state) do
    from_id..to_id
    |> Enum.each(fn this_id ->
      # Process.sleep(300)
      start_single(server_ip, server_port, name_prefix, this_id, born_state)
    end)
  end
end
