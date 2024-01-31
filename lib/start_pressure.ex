defmodule StartPressure do
  require Logger

  def go(server_ip, server_port, name_prefix, from_id, to_id, ai) do
    case Client.tcp_connect(server_ip, server_port) do
      {:ok, conn} ->
        Client.tcp_close(conn)
        strategy(:once_time, server_ip, server_port, name_prefix, from_id, to_id, ai)

      _ ->
        Logger.warning("cannot connect #{inspect(server_ip)}:#{inspect(server_port)}")
    end
  end

  def strategy(:once_time, server_ip, server_port, name_prefix, from_id, to_id, ai) do
    from_id..to_id
    |> Enum.to_list()
    |> Enum.chunk_every(100)
    |> Enum.each(fn this_list ->
      this_list
      |> Enum.each(fn this_id ->
        # Process.sleep(300)
        start_single(server_ip, server_port, name_prefix, this_id, ai)
      end)

      Process.sleep(1000)
    end)
  end

  def start_single(server_ip, server_port, name_prefix, id, ai) do
    account = name_prefix <> "#{id}"

    start_time = Utils.timestamp(:ms)

    gid =
      case "#{id}" |> String.at(0) do
        "1" -> 1
        "2" -> 2
        "3" -> 3
        _ -> nil
      end

    if is_nil(gid) do
      Logger.warning("gid error, id: #{id}")
    else
      Avatar.Supervisor.start_child({server_ip, server_port, account, gid, ai},
        name: {:global, {:name, Guid.name(account)}}
      )

      end_time = Utils.timestamp(:ms)
      Logger.info("login account: #{inspect(account)}, login_used: #{end_time - start_time}")
    end
  end
end
