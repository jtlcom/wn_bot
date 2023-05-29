defmodule Ets.RepoAPI do
  @moduledoc ~S"""
  ets泛型API模块

  * 使用方法: use Ets.RepoAPI, name: etsname, opts: [:named_table, :public, {:write_concurrency, :auto}, {:read_concurrency, true}]
    * 当auto_update_db=true时，save/insert/delete/clear/insert_one/delete_one等相关操作都会更新数据库, 默认为nil
    * opts是ets的创建参数, 默认为[:named_table, :public]
    * 存取db数据时如需要特殊转换的结构，可重构对应转换函数
      * encode/1
      * decode/1

  db数据转ets数据
  ```elixir
  decode({k, v}) :: {k, v}
  ```

  ets数据转db数据
  ```elixir
  encode({k, v}) :: {k, v}
  ```

  初始化
  ```elixir
  init(from_db? :: boolean) :: :ok | :invalid_table_name | :table_has_exist
  ```

  ets数据保存到dets里
  ```elixir
  save_to_dets(name :: atom) :: :ok
  ```

  从dets里加载数据到ets
  ```elixir
  load_from_dets(name :: atom) :: :ok
  ```

  ets数据入库
  ```elixir
  ets_to_db() :: :ok
  ```

  ets是否存在
  ```elixir
  exist?(name :: atom) :: boolean
  ```

  key是否存在
  ```elixir
  key_exist?(key :: any) :: boolean
  ```

  初始化key的值
  ```elixir
  init_key(key :: atom, val :: any, force :: boolean) :: :ok
  ```

  根据key查询
  ```elixir
  load(key :: any, default :: any) :: any
  ```

  根据key查询数据, 方便 {key, value} 形式的值使用
  ```elixir
  load_value(key :: any, default :: any) :: any
  ```

  查询所有数据
  ```elixir
  load_all() :: list
  ```

  查询所有数据, 方便 {key, value} 形式的值直接取所有key的值
  ```elixir
  load_all_value() :: list
  ```

  保存数据
  ```elixir
  save(record :: tuple) :: :ok
  ```

  保存数据
  ```elixir
  save(k :: any, v :: any) :: :ok
  ```

  插入数据
  ```elixir
  insert(record :: tuple) :: :ok
  ```

  插入数据
  ```elixir
  insert(k :: any, v :: any) :: :ok
  ```

  value里插入或修改一条数据
  ```elixir
  insert_one(key :: any, val_k :: any, val_v :: any) :: {:ok, any} | :failed | :existed
  ```

  筛选删除数据
  ```elixir
  delete_by_ms(match_spec :: any) :: :ok
  ```

  删除数据
  ```elixir
  delete(k :: any) :: :ok
  ```

  value里插入删除value里的一条数据或修改一条数据
  ```elixir
  delete_one(key :: any, val_k :: any) :: {:ok, any} | :failed | :not_exist
  ```

  删除全部数据
  ```elixir
  clear() :: :ok
  ```

  删除全部数据
  ```elixir
  clear() :: :ok
  ```

  查找数据
  ```elixir
  find(match_spec :: any, limit :: :infinity | integer) :: any
  ```

  筛选获取数量
  ```elixir
  count(match_spec :: any) :: integer
  ```

  获取数量
  ```elixir
  count() :: integer
  ```

  从尾部插入
  ```elixir
  append(key, value, allow_repeat? \\ true) :: :ok | :failed | :existed
  ```

  从头部插入
  ```elixir
  push(key, value, allow_repeat? \\ true) :: :ok | :failed | :existed
  ```

  从头部弹出
  ```elixir
  pop(key) :: any | :failed
  ```

  删除value
  ```elixir
  delete_in(key, value) :: :ok | :failed | :not_exist
  ```

  获取计数器值
  ```elixir
  counter(key :: :counter | any, default :: any) :: integer
  ```

  计数器加
  ```elixir
  counter_inc(key :: :counter | any, step :: integer, default :: any) :: integer
  ```

  计数器减
  ```elixir
  counter_dec(key :: :counter | any, step :: integer, default :: any) :: integer
  ```
  """
  defmacro __using__(args) do
    name = Keyword.get(args, :name)

    {name, collection} =
      case name do
        n when is_bitstring(n) -> {String.to_atom(name), name}
        n when is_atom(n) -> {name, Atom.to_string(name)}
        _ -> {name, "#{name}"}
      end

    opts = Keyword.get(args, :opts, [:named_table, :public])

    quote do
      @name unquote(name)
      @collection unquote(collection)
      @opts unquote(opts)

      require Logger
      require Utils

      def collection, do: @collection

      @doc """
      初始化, 创建ets, 可选加载db数据到ets
      """
      @spec init(from_db? :: boolean) :: :ok | :invalid_table_name | :table_has_exist

      def init(from_db? \\ false) do
        cond do
          not is_atom(@name) ->
            :invalid_table_name

          exist?() ->
            :table_has_exist

          true ->
            :ets.new(@name, @opts)
            :ok
        end
      end

      def encode({k, v}) when is_integer(k) do
        {k, v}
      end

      def encode({k, v}) do
        {k, v}
      end

      def decode({k, v}) do
        {k, v}
      end

      @doc """
      ets数据保存到dets里
      """
      @spec save_to_dets(name :: atom) :: :ok
      def save_to_dets(name \\ @name) do
        :dets.open_file(name, type: :set)
        :dets.insert(name, load_all())
        :dets.close(name)
        :ok
      end

      @doc """
      从dets里加载数据到ets
      """
      @spec load_from_dets(name :: atom) :: :ok
      def load_from_dets(name \\ @name) do
        :dets.open_file(name, type: :set)
        :dets.to_ets(name, @name)
        :dets.close(name)
        :ok
      end

      @doc """
      ets是否存在
      """
      @spec exist?(name :: atom) :: boolean
      def exist?(name \\ @name), do: :ets.info(name) != :undefined

      @doc """
      key是否存在
      """
      @spec key_exist?(key :: any) :: boolean
      def key_exist?(key), do: :ets.lookup(@name, key) != []

      @doc """
      初始化key的值
      """
      @spec init_key(key :: atom, val :: any, force :: boolean) :: :ok
      def init_key(key, val, force \\ false) do
        if force || load_value(key) == nil do
          insert(key, val)
        end

        :ok
      end

      @doc """
      根据key查询
      """
      @spec load(key :: any, default :: any) :: any
      def load(key, default \\ nil) do
        :ets.lookup(@name, key) |> Enum.at(0, default)
      end

      @doc """
      根据key查询数据, 方便 {key, value} 形式的值使用
      """
      @spec load_value(key :: any, default :: any) :: any
      def load_value(key, default \\ nil) do
        case load(key) do
          {^key, value} -> value
          v when is_tuple(v) -> v |> Tuple.delete_at(0)
          _ -> default
        end
      end

      @doc """
      查询所有数据
      """
      @spec load_all() :: list
      def load_all(), do: :ets.tab2list(@name)

      @doc """
      查询所有数据, 方便 {key, value} 形式的值直接取所有key的值
      """
      @spec load_all_value() :: list
      def load_all_value() do
        load_all()
        |> Enum.map(fn
          {_k, v} -> v
          r -> r |> Tuple.delete_at(0)
        end)
      end

      @doc """
      保存数据
      """
      @spec save(data :: tuple) :: :ok

      def save(data) do
        :ets.insert(@name, data)

        :ok
      end

      @doc """
      保存数据
      """
      @spec save(k :: any, v :: any) :: :ok
      def save(k, v), do: save({k, v})

      @doc """
      插入数据
      """
      @spec insert(record :: tuple) :: :ok
      def insert(record), do: save(record)

      @doc """
      插入数据
      """
      @spec insert(k :: any, v :: any) :: :ok
      def insert(k, v), do: save(k, v)

      @doc """
      value里插入或修改一条数据
      """
      @spec insert_one(key :: any, val_k :: any, val_v :: any) :: {:ok, any} | :failed | :existed

      def insert_one(key, val_k, val_v \\ nil) do
        case load_value(key) do
          data when is_map(data) ->
            new_data = data |> Map.put(val_k, val_v)
            :ets.insert(@name, {key, new_data})
            {:ok, new_data}

          data when is_list(data) ->
            if val_k not in data do
              new_data = data ++ [val_k]
              :ets.insert(@name, {key, new_data})
              {:ok, new_data}
            else
              :existed
            end

          _ ->
            :failed
        end
      end

      @doc """
      筛选删除数据
      """
      @spec delete_by_ms(match_spec :: any) :: any()
      def delete_by_ms(match_spec) do
        :ets.select_delete(@name, match_spec)
      end

      @doc """
      删除数据
      """
      @spec delete(k :: any) :: true
      def delete(k) do
        :ets.delete(@name, k)
      end

      @doc """
      删除value里的一条数据
      """
      @spec delete_one(key :: any, val_k :: any) :: {:ok, any} | :failed | :not_exist
      def delete_one(key, val_k) do
        case load_value(key) do
          data when is_map(data) ->
            if Map.has_key?(data, val_k) do
              new_data = data |> Map.delete(val_k)
              :ets.insert(@name, {key, new_data})
              {:ok, new_data}
            else
              :not_exist
            end

          data when is_list(data) ->
            if val_k in data do
              new_data = data -- [val_k]
              :ets.insert(@name, {key, new_data})
              {:ok, new_data}
            else
              :not_exist
            end

          _ ->
            :failed
        end
      end

      @doc """
      删除全部数据
      """
      @spec clear() :: true
      def clear() do
        :ets.delete_all_objects(@name)
      end

      @doc """
      删除全部数据
      """
      @spec has_record?(k :: any) :: boolean
      def has_record?(k) do
        :ets.member(@name, k)
      end

      @doc """
      查找数据
      """
      @spec find(match_spec :: any, limit :: :infinity | integer) :: any
      def find(match_spec, limit \\ :infinity) do
        select(match_spec, limit)
      end

      @doc """
      筛选获取数量
      """
      @spec count(match_spec :: any) :: integer
      def count(match_spec) do
        :ets.select(@name, match_spec) |> length
      end

      @doc """
      获取数量
      """
      @spec count() :: integer
      def count() do
        :ets.info(@name, :size)
        |> case do
          size when is_integer(size) ->
            size

          _ ->
            0
        end
      end

      @doc """
      从尾部插入
      """
      def append(key, value, allow_repeat? \\ true) do
        case load_value(key, []) do
          cur when is_list(cur) ->
            if allow_repeat? do
              insert(key, cur ++ List.wrap(value))
            else
              if value not in cur do
                insert(key, cur ++ List.wrap(value))
              end
            end

            :ok

          _ ->
            :failed
        end
      end

      @doc """
      从头部插入
      """
      def push(key, value, allow_repeat? \\ true) do
        case load_value(key, []) do
          cur when is_list(cur) ->
            if allow_repeat? do
              insert(key, [value | cur])
            else
              if value not in cur do
                insert(key, [value | cur])
              end
            end

            :ok

          _ ->
            :failed
        end
      end

      @doc """
      从头部弹出
      """
      def pop(key) do
        case load_value(key, []) do
          [value | list] ->
            insert(key, list)
            value

          [] ->
            nil

          _ ->
            :failed
        end
      end

      @doc """
      删除value
      """
      def delete_in(key, value) do
        case load_value(key, []) do
          [_ | _] = list ->
            if value in list do
              insert(key, list -- [value])
            else
              :not_exist
            end

          [] ->
            :not_exist

          _ ->
            :failed
        end
      end

      @doc """
      获取计数器值
      """
      @spec counter(key :: :counter | any, default :: any) :: integer
      def counter(key \\ :counter, default \\ 0), do: load_value(key) || default

      @doc """
      计数器加
      """
      @spec counter_inc(key :: :counter | any, step :: integer, default :: any) :: integer
      def counter_inc(key \\ :counter, step \\ 1, default \\ 0) do
        :ets.update_counter(@name, key, step, {key, default})
      end

      @doc """
      计数器减
      """
      @spec counter_dec(key :: :counter | any, step :: integer, default :: any) :: integer
      def counter_dec(key \\ :counter, step \\ 1, default \\ 0) do
        :ets.update_counter(@name, key, -step, {key, default})
      end

      defp select(match_spec, :infinity) do
        :ets.select(@name, match_spec)
      end

      defp select(match_spec, count) when is_integer(count) and count > 0 do
        :ets.select(@name, match_spec, count)
      end

      defp select(_, _), do: []

      defoverridable encode: 1, decode: 1
    end
  end
end
