defmodule Debug do
  def pid_of_global(id) do
    :global.whereis_name(id)
  end

  def state_of_pid(p) do
    :sys.get_state(p)
  end

  def avatar_info(id) do
    case pid_of_global(id) do
      pid when is_pid(pid) ->
        state_of_pid(pid)

      _ ->
        {:error, :avatar_offline}
    end
  end

  def avatar_info(id, props) when is_list(props) do
    case avatar_info(id) do
      {:error, _reason} = res -> res
      map -> Map.take(map, props)
    end
  end

  def avatar_info(id, prop) when is_atom(prop) do
    avatar_info(id, [prop])
  end

  defguardp can_replace?(path, func) when is_list(path) and is_function(func)

  def replace_avatar_data(id, path, func) when can_replace?(path, func) do
    case avatar_info(id) do
      data when is_map(data) ->
        {session, changed} =
          get_and_update_in(data, path, fn old -> {old, func.(old)} end)
          |> elem(1)
          |> Map.pop(:session)

        pid_of_global(id)
        |> :sys.replace_state(fn _old -> {id, session, changed} end)

        :ok

      other ->
        other
    end
  end

  def replace_avatar_data(id, path, new) when is_list(path) do
    case avatar_info(id) do
      data when is_map(data) ->
        {session, changed} = put_in(data, path, new) |> Map.pop(:session)
        pid_of_global(id) |> :sys.replace_state(fn _old -> {id, session, changed} end)
        :ok

      other ->
        other
    end
  end

  def global_name(pid) do
    pairs =
      :global.registered_names()
      |> Enum.map(fn name ->
        pid = pid_of_global(name)
        {name, pid}
      end)

    case Enum.find(pairs, fn {name, p} -> is_integer(name) and p == pid end) do
      {name, _pid} -> name
      nil -> nil
    end
  end

  def onlines() do
    Supervisor.which_children(Avatars)
    |> Enum.map(fn info ->
      pid = elem(info, 1)
      id = global_name(pid)
      name = avatar_info(id, :name)
      %{id: a_id} = avatar_info(id, :id)
      {id, a_id, name}
    end)
  end

  def dicts_of_pid(p) when is_pid(p) do
    Process.info(p)
    |> Keyword.get(:dictionary)
    |> Map.new()
  end

  def dicts_of_avatar(id) do
    pid_of_global(id)
    |> Process.info()
    |> Keyword.get(:dictionary)
    |> Map.new()
  end

  def dicts_of_pid(p, key) when is_pid(p) do
    dicts_of_pid(p) |> Map.get(key)
  end

  def dicts_of_pid(id, key) do
    dicts_of_avatar(id) |> Map.get(key)
  end

  def reload(file_name) do
    IEx.Helpers.c(file_name)
  end

  def flag(env, value) do
    Application.put_env(:my_server, env, value)
  end

  def flag_current(flag) do
    Application.get_env(:my_server, flag)
  end

  def call(id, mod, func, args) do
    Router.route(id, {{mod, func}, args |> List.wrap})
  end

  def execute(times, mod, func, args) do
    mod = Module.concat(:Elixir, mod)
    :timer.tc(fn ->
      Enum.each(1..times, fn _ ->
      apply(mod, func, args |> List.wrap)
      end)
    end)
  end
end