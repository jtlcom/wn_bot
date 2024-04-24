defmodule Client do
  require Logger

  def packet, do: 4

  def tcp_close(conn) do
    is_port(conn) && :gen_tcp.close(conn)
  end

  def tcp_connect(server_ip, server_port) do
    Logger.info("tcp_connect")

    :gen_tcp.connect(
      server_ip,
      server_port,
      [
        :binary,
        packet: packet(),
        active: true,
        recbuf: 1024 * 1024 * Application.get_env(:whynot_bot, :recv_buff, 20),
        keepalive: true,
        nodelay: true
      ],
      60000
    )
  end

  def login_post(server_ip, account) do
    login_url =
      case "#{server_ip}" |> String.split(".") do
        ["192", "168" | _] ->
          "http://192.168.1.92:8080/auth/whynot"

        # 外网测试
        ["42", "193" | _] ->
          "http://42.193.252.182:8008/auth/whynot"

        ["159", "75" | _] ->
          "http://159.75.204.224:8018/auth/whynot"

          # taptap
          # ["159", "75" | _] ->
          #   "http://159.75.177.225:8008/auth/whynot"

          # _ ->
          #   "http://192.168.1.92:8080/auth/whynot"
      end

    HTTPoison.post(
      login_url,
      %{"account" => account, "password" => "111111"} |> URI.encode_query(),
      [{"Content-Type", "application/x-www-form-urlencoded"}],
      timeout: 5000
    )
  end

  def send_msg(conn, msg, is_encrypt? \\ true) do
    # Process.sleep(50)
    # t1 = Utils.timestamp(:ms)
    id = Process.get(:cmd_dic, -1) + 1
    Process.put(:cmd_dic, id)
    bin = SimpleMsgPack.pack!(msg)

    case is_encrypt? and Process.get(:encrypt_key) do
      key when is_list(key) -> Xxtea.encrypt(bin, key)
      _ -> bin |> IO.iodata_to_binary()
    end

    # bin = :erlang.term_to_binary(msg)
    bin1 = <<id::unsigned-integer-size(32), bin::binary>>
    # Logger.info fn -> "bin1 is #{inspect(bin1)}" end
    # :gen_tcp.send(conn, :zlib.compress(bin1))
    res = :gen_tcp.send(conn, bin1)
    # Port.command(conn, bin1)

    case res do
      {:error, :timeout} ->
        Logger.error("tcp send timeout")

      {:error, send_error} ->
        Logger.error("send error is #{inspect(send_error)}")

      _ ->
        aid = Process.get(:svr_aid, 0)
        Logger.debug("send message------------------------------------------------:
        \t\t avatar: \t #{aid}
        \t\t account: \t #{Process.get(:account, nil)}
        \t\t time: \t #{inspect(:calendar.local_time())}
        \t\t msg: \t #{inspect(msg, pretty: true, limit: :infinity)}
        ")
        :ok
    end
  end
end
