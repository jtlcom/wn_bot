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

  def avatar_write(aid, account, msg) do
    content =
      "\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t send message------------------------------------------------:
\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t avatar: \t #{aid}
\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t account: \t #{account}
\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t time: \t #{inspect(:calendar.local_time())}
\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t msg: \t #{inspect(msg, pretty: true, limit: :infinity)}\n
"

    AvatarLog.new_log(account, content)
  end
end
