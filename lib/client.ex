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

  def lan_ip do
    case :inet.getif() do
      {:ok, [{ip, _, _} | _]} -> ip |> Tuple.to_list() |> Enum.join(".")
      _ -> "127.0.0.1"
    end
  end

  def login_post(account, platform, login_url) do
    login_url = "#{login_url}/auth/#{platform}"

    body =
      case platform do
        "msdk" ->
          %{
            "openid" => account,
            "token" => account,
            "claim" => %{
              "device_id" => account,
              "device_os" => 1,
              "app_version" => "0.12.2",
              "res_version" => "0.12.2.2",
              "user_agent" => "",
              "device_language" => "ChineseSimplified",
              "ipv4" => lan_ip(),
              "ipv6" => "",
              "game_language" => 1,
              "login_channel" => "00000000",
              "channelid" => 1,
              "country" => "cn",
              "open_key" => account,
              "old_caid" => "",
              "ad_id" => "-12",
              "pf" => account,
              "pf_key" => account,
              "system_software" => "Android OS 12",
              "session_type" => "itop",
              "session_id" => "itopid",
              "reg_channel" => "00000000",
              "offer_id" => account,
              "oaid" => "-12",
              "new_caid" => "",
              "device" => "whynot"
            }
          }

        "jx" ->
          %{
            "token" => account,
            "claim" => %{
              "oaid" => account,
              "ipv4" => lan_ip(),
              "ad_id" => account,
              "device_id" => account,
              "ipv6" => "",
              "game_language" => 1,
              "app_version" => "0.12.2",
              "system_software" => "Android OS 12",
              "channelid" => 0,
              "token" => account,
              "login_channel" => "0",
              "device_language" => "ChineseSimplified",
              "reg_channel" => "0",
              "res_version" => "0.12.2.2",
              "device_os" => 1,
              "country" => "cn",
              "device" => "whynot"
            }
          }

        _ ->
          %{"account" => account, "password" => "111111"}
      end
      |> Jason.encode!()

    HTTPoison.post(login_url, body, [{"Content-Type", "application/json"}], timeout: 5000)
  end

  def send_msg(conn, msg, is_encrypt? \\ true) do
    # Process.sleep(50)
    # t1 = Utils.timestamp(:ms)
    id = Process.get(:cmd_dic, -1) + 1
    Process.put(:cmd_dic, id)
    bin = SimpleMsgPack.pack!(msg)

    bin =
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
        case msg do
          ["ping" | _] ->
            :ok

          _ ->
            aid = Process.get(:svr_aid, 0)
            account = Process.get(:account, nil)

            AvatarLog.avatar_write(aid, account, msg)
        end

        :ok
    end
  end
end
