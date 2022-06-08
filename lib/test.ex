defmodule Test do
  require Logger

  def onlines_count() do 
    Supervisor.which_children(Avatars)
    |> length()
  end

  def get_mnesia_pid_num() do
    Mnesiam.AvatarLines.get_data(:lines) |> Map.values() |> List.flatten |> length
  end

  def get_max_line_id() do
    Mnesiam.AvatarLines.get_max_line_id()
  end

  def test1() do
    bin = <<146, 163, 101, 118, 116, 151, 163, 109, 111, 118, 207, 0, 0, 0, 35, 41, 0, 10, 42, 99, 204, 154, 253, 4, 6>>

    # <<146, 163, 101, 118, 116, 146, 163, 111, 117, 116, 207, 0, 0, 0, 35, 43, 0, 36,
    # 89>>
    # <<146, 163, 101, 118, 116, 147, 165, 112, 116, 95, 104, 112, 207, 0, 0, 0, 35,
    # 43, 0, 36, 89, 205, 38, 42>>
    # <<146, 164, 105, 110, 102, 111, 147, 168, 109, 115, 103, 58, 104, 105, 110, 116,
    # 0, 130, 164, 97, 114, 103, 115, 145, 129, 162, 105, 100, 117, 164, 104, 105,
    # 110, 116, 206, 1, 49, 52, 209>>
    # <<146, 169, 109, 115, 103, 58, 119, 111, 114, 108, 100, 164, 108, 97, 108, 97>>
    # <<146, 163, 101, 118, 116, 147, 187, 114, 111, 108, 101, 103, 114, 111, 117,
    # 112, 58, 114, 101, 109, 111, 118, 101, 95, 102, 114, 111, 109, 95, 103, 114,
    # 111, 117, 112, 1, 3>>
      # <<146, 163, 101, 118, 116, 147, 168, 100, 101, 108, 95, 98, 117, 102, 102, 207, 0, 0, 0, 35,
      #   41, 0, 12, 33, 145, 206, 23, 215, 167, 40>>

    # quote(do: [0b101::3, length::5, value::size(length)-bytes]),
    # quote(do: [0xD9, length::8, value::size(length)-bytes]),
    # quote(do: [0xDA, length::16, value::size(length)-bytes]),
    # quote(do: [0xDB, length::32, value::size(length)-bytes]),

    case bin do
      # <<146, 163, "evt", 147, 165, "pt_hp", 0xCF, id::64, reset::bits>> ->
      #   IO.inspect ["evt", ["pt_hp", id] ++ SimpleMsgPack.pack!(reset)]

      # <<146, 164, "info", 147, 168, "msg:hint", reset::bits>> ->
      #   Logger.warn("value is #{inspect("msg:hint")}")

      # <<146, 169, "msg:world", reset::bits>> ->
      #   Logger.warn("value is #{inspect("msg:world")}")

      # <<146, 163, "evt", ll::size(8), lll::size(8), "del_buff", reset::bits>> ->
      #   Logger.warn("value is #{inspect("del_buff")}")

      # <<146, 163, "evt", ll::size(8), lll::size(8), "rolegroup:remove_from_group", llll::size(8), lllll::size(8), reset::bits>> ->
      #   Logger.warn("value is #{inspect(SimpleMsgPack.pack!(reset))}")

      <<146, 163, "evt", 151, 163, "mov", 0xCF, id::64, reset::bits>> ->
        IO.inspect ["evt"] ++ [[id] ++ SimpleMsgPack.unpack!(reset)]

      <<146, 163, "evt", 146, 163, "out", 0xCF, id::64>> ->
        IO.inspect ["evt", ["out", id]]

      # <<146, 163, "evt", reset::bits>> ->
      #   ["evt"] ++ SimpleMsgPack.pack!(reset)

      # <<146, 164, "info", reset::bits>> ->
      #   ["info"] ++ SimpleMsgPack.pack!(reset)

      # <<146, 163, "evt", ll::8, lll::8, 0b101::3, length::5, value::size(length)-bytes, reset::bits>> ->
      #   Logger.warn("value is #{inspect(value)}")
      # <<146, 163, "evt", ll::8, lll::8, 0xD9, length::8, value::size(length)-bytes, reset::bits>> ->
      #   Logger.warn("value is #{inspect(value)}")
      # <<146, 163, "evt", ll::8, lll::8, 0xDA, length::16, value::size(length)-bytes, reset::bits>> ->
      #   Logger.warn("value is #{inspect(value)}")
      # <<146, 163, "evt", ll::8, lll::8, 0xDB, length::32, value::size(length)-bytes, reset::bits>> ->
      #   Logger.warn("value is #{inspect(value)}")

      <<0b1001::4, _length::4, rest::bits>> ->
        Logger.warn("value is #{inspect(rest)}")

      <<0b101::3, length::5, value::size(length)-bytes, _reset::bytes>> ->
        Logger.warn("value is #{inspect(value)}")

      <<0xD9, length::8, value::size(length)-bytes, _reset::bytes>> ->
        Logger.warn("value is #{inspect(value)}")

      <<0xDA, length::16, value::size(length)-bytes, _reset::bytes>> ->
        Logger.warn("value is #{inspect(value)}")

      <<0xDB, length::32, value::size(length)-bytes, _reset::bytes>> ->
        Logger.warn("value is #{inspect(value)}")

      _ ->
        Logger.warn("ok.....")
        :ok
    end

    SimpleMsgPack.unpack!(bin)
  end


end
