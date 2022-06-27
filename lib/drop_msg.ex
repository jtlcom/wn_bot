defmodule DropMsg do
  require Logger

  def match(bin) do
    # IO.inspect("correct msg should be : #{inspect(SimpleMsgPack.unpack!(bin))}")

    case bin do
      # no_need_handle
      # <<146, 163, "evt", 151, 163, "dmg", reset::bits>> ->
      #   :no_need_handle

      <<146, 163, "evt", 149, 164, "cast", _reset::bits>> ->
        :no_need_handle

      <<146, 163, "evt", 149, 164, "trans", _reset::bits>> ->
        :no_need_handle

      <<146, 163, "evt", 149, 165, "trans", _reset::bits>> ->
        :no_need_handle

      # <<146, 163, "evt", 146, 163, "out", reset::bits>> ->
      #   :no_need_handle

      <<147, 169, "msg:world", _reset::bits>> ->
        :no_need_handle

      # <<146, 169, "msg:point", reset::bits>> ->
      #   :no_need_handle

      <<146, 164, "info", 147, 168, "msg:hint", _reset::bits>> ->
        :no_need_handle

      # handle
      # <<146, 163, "evt", 151, 163, "mov", 0xCF, id::64, reset::binary>> ->
      #   ["evt"] ++ [["mov", id] ++ decode_move_reset(reset, [])]

      # <<146, 163, "evt", 147, 165, "pt_hp", 0xCF, id::64, reset::bits>> ->
      #   ["evt", ["pt_hp", id] ++ SimpleMsgPack.unpack!(reset)]

      # <<146, 163, "evt", 146, 163, "out", 0xCF, id::64>> ->
      #   ["evt", ["pt_hp", id]]

      # 少解一层
      # <<146, 163, "evt", reset::bits>> ->
      #   ["evt"] ++ [SimpleMsgPack.unpack!(reset)]

      # <<146, 164, "info", reset::bits>> ->
      #   ["info"] ++ [SimpleMsgPack.unpack!(reset)]

      _ ->
        SimpleMsgPack.unpack!(bin)
        # Logger.warn("re is #{inspect(re)}, bin is #{inspect(bin)}")
    end
  end

  # defp decode_move_reset(<<>>, result) do
  #   result
  # end

  # defp decode_move_reset(<<0xCC, int::8, reset::bits>>, result) do
  #   decode_move_reset(reset, result ++ [int])
  # end

  # defp decode_move_reset(<<0b111::3, value::5, reset::bits>>, result) do
  #   int = value - 0b100000
  #   decode_move_reset(reset, result ++ [int])
  # end

  # defp decode_move_reset(<<int::8, reset::bits>>, result) do
  #   decode_move_reset(reset, result ++ [int])
  # end
end
