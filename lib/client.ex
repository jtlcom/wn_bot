defmodule Client do
  # import ExchangeCode

  require Logger
  # @timeout 9_999_999

  def start(id, line_id, type) do
    Realm.start_avatar(id, line_id, type)
  end

  def send_msg(conn, msg) do
    # Process.sleep(50)
    # t1 = Utils.timestamp(:ms)
    id = Process.get(:cmd_dic, -1) + 1
    Process.put(:cmd_dic, id)
    Upload.res_log(msg)
    bin = SimpleMsgPack.pack!(msg) |> IO.iodata_to_binary()
    # bin = :erlang.term_to_binary(msg)
    # Logger.info("000000")
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
        :ok
    end

    MsgCounter.res_count_add()
    # t2 = Utils.timestamp(:ms)
    # (t2 - t1 > 3000) && IO.inspect("id: #{id}, lala #{(t2 - t1)} #{inspect msg}")
  end
end
