defmodule Group do

  def create_group(lines \\ {:by_num, 100}) do
    # 创建军团
    ["rolegroup:create_group"]
    |> Realm.broadcast_avatars_handle_after(lines, 1000)
  end
end
