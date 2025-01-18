defmodule AvatarLog do
  require Logger

  def new_log(account, content) do
    # Logger.debug(content)

    case Application.get_env(:whynot_bot, :is_write_avatar) and is_binary(account) and
           String.split(account, "_") do
      [name_prefix, gid, id_index] ->
        id_range = div(String.to_integer(id_index) - 1, 100)
        id_class = "#{id_range * 100 + 1}..#{(id_range + 1) * 100}"
        path = "./log/#{name_prefix}/gid_#{gid}/#{id_class}/#{account}.log"

        if File.exists?(path) do
          File.write(path, content, [:append])
        else
          File.mkdir_p("./log/#{name_prefix}/gid_#{gid}/#{id_class}")
          File.write(path, content, [:append])
        end

      _ ->
        nil
    end
  end
end
