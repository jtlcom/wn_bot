defmodule Client do
  require Logger
  # @timeout 9_999_999

  def send_msg(conn, msg) do
    # Process.sleep(50)
    # t1 = Utils.timestamp(:ms)
    id = Process.get(:cmd_dic, -1) + 1
    Process.put(:cmd_dic, id)
    bin = SimpleMsgPack.pack!(msg) |> IO.iodata_to_binary()
    # bin = :erlang.term_to_binary(msg)
    bin1 = <<id::unsigned-integer-size(32), bin::binary>>
    # Logger.info fn -> "bin1 is #{inspect(bin1)}" end
    # :gen_tcp.send(conn, :zlib.compress(bin1))
    res = :gen_tcp.send(conn, bin1)
    # Port.command(conn, bin1)

    case res do
      {:error, :timeout} ->
        Logger.info("tcp send timeout")

      {:error, send_error} ->
        Logger.info("send error is #{inspect(send_error)}")

      _ ->
        aid = Process.get(:svr_aid, 0)
        Logger.info("send message------------------------------------------------:
        \t\t avatar: \t #{aid}
        \t\t time: \t #{inspect(:calendar.local_time())}
        \t\t msg: \t #{inspect(msg, pretty: true, limit: :infinity)}
        ")
        :ok
    end
  end
end
