defmodule StartPressure do
  require Logger

  def go(server_ip, server_port, name_prefix, gid, from_id, to_id, ai, platform, login_url) do
    from_id..to_id
    |> Enum.to_list()
    |> Enum.chunk_every(100)
    |> Enum.each(fn this_list ->
      this_list
      |> Enum.each(fn this_id ->
        # Process.sleep(300)
        start_single(server_ip, server_port, name_prefix, gid, this_id, ai, platform, login_url)
      end)

      Process.sleep(100)
    end)
  end

  def start_single(server_ip, server_port, name_prefix, gid, id, ai, platform, login_url) do
    account = "#{name_prefix}_#{gid}_#{id}"
    start_time = Utils.timestamp(:ms)

    if is_nil(gid) do
      Logger.warning("gid error, id: #{id}")
    else
      Avatars.start_child({server_ip, server_port, account, gid, ai, platform, login_url})

      end_time = Utils.timestamp(:ms)
      Logger.info("login account: #{inspect(account)}, login_used: #{end_time - start_time}")
    end
  end
end
