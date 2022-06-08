defmodule Mnesiam.AvatarLines do
  @table :avatar_line
  @attributes [:key, :data]
  @teble_index :key
  use Mnesia.Base, [table: @table, attributes: @attributes, teble_index: @teble_index]

  def get_max_line_id() do
    lines = (Mnesiam.AvatarLines.get_data(:lines) || %{}) |> Map.keys() |> List.delete(:chat_robots)
    lines == [] && 0 || Enum.max(lines)
  end

end