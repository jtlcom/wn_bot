defmodule Group do

  def create_group(lines \\ {:by_num, 100}) do
    # 创建军团
    ["rolegroup:create_group"]
    |> Realm.broadcast_avatars_handle_after(lines, 1000)
  end

  def join_group(lines \\ :all) do
    ["groups:group_list_to_client", 0]
    |> Realm.broadcast_avatars_delay(lines, 200)
  end

  def join_group_by_index(index, lines \\ :all) do
    {:join_group, index}
    |> Realm.broadcast_avatars_handle_after(lines, 20)
  end

end