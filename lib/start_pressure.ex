defmodule StartPressure do
  require Logger
  # StartPressure.go('192.168.1.129', 6666, "bot_1_", 1, 2, 1)
  def go(server_ip, server_port, name_prefix, from_id, to_id, ai) do
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
    gid = div(id, 1000) |> rem(3) |> Kernel.+(1)

    Avatar.Supervisor.start_child(
      {server_ip, server_port, account, gid, ai},
      name: {:global, {:name, Guid.name(account)}}
    )

    end_time = Utils.timestamp(:ms)
    Logger.info("login account: #{inspect(account)}, login_used: #{end_time - start_time}")
  end
end
