defmodule AutoReply do
  use GameDef

  def get_reply_msgs(msg) do
    GameDef.get_response_reply(msg)
    |> Enum.map(fn %{ "resultType" => type, "values" => values} ->
      values[type] || nil
    end)
    |> Enum.reject(&is_nil/1)
  end
end