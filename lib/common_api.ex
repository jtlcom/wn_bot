defmodule CommonAPI.Macro do
  defmacro func_info() do
    quote do
      [{_, func_info}] = :erlang.process_info(self(), [:current_function])
      func_info
    end
  end

  defmacro ensure_module(mod) do
    if Mix.env() == :dev do
      quote do: Code.ensure_loaded(unquote(mod))
    end
  end

  defmacro loop(condition, clauses) do
    optimize_boolean(
      quote do
        case unquote(condition) do
          x when :"Elixir.Kernel".in(x, [false, nil]) -> nil
          _ -> unquote(clauses)
        end
      end
    )
  end

  defp optimize_boolean({:case, meta, args}) do
    {:case, [{:optimize_boolean, true} | meta], args}
  end
end

defmodule CommonAPI do
  @moduledoc ~S"""
  公共函数模块

  """
  require Logger
  require CommonAPI.Macro

  @day_sec 24 * 3600
  @week_sec 7 * 24 * 3600
  @zero_day_time 946_656_000
  @zero_week_time 946_828_800

  @doc """
  获取mix编译环境类型
  """
  @spec env() :: atom
  def env() do
    unquote(Mix.env())
  end

  @doc """
  字符串转atom，字符串列表转atom列表
  """
  @spec to_atom(s :: String.t() | list) :: atom | list
  def to_atom(s) do
    cond do
      is_binary(s) ->
        try do
          String.to_existing_atom(s)
        rescue
          _ ->
            String.to_atom(s)
        end

      is_list(s) ->
        Enum.map(s, &to_atom(&1))

      true ->
        s
    end
  end

  @doc """
  list转tuple, layer为转换层级，默认为-1，无限层级
  """
  @spec to_tuple(list :: list | tuple, layer :: integer) :: tuple
  def to_tuple(list, layer \\ -1)

  def to_tuple(list, layer) when is_list(list) do
    case layer do
      0 -> list
      _ -> list |> Enum.map(&to_tuple(&1, layer - 1)) |> List.to_tuple()
    end
  end

  def to_tuple(tuple, _layer) when is_tuple(tuple) do
    tuple
  end

  def to_tuple(t, _layer) do
    t
  end

  @doc """
  tuple转list, 可以加标记便于转回tuple
  """
  @spec to_list(t :: any, add_tag? :: boolean()) :: list
  def to_list(t, add_tag? \\ false)

  def to_list(t, add_tag?) when is_list(t) do
    t |> Enum.map(&to_list(&1, add_tag?))
  end

  def to_list(t, add_tag?) when is_struct(t) do
    mod = Map.get(t, :__struct__)
    t |> Map.from_struct() |> Map.put(:struct, mod) |> to_list(add_tag?)
  end

  def to_list(t, add_tag?) when is_map(t) do
    t |> Enum.map(fn {k, v} -> {to_list(k, add_tag?), to_list(v, add_tag?)} end) |> Map.new()
  end

  def to_list(t, add_tag?) when is_tuple(t) do
    t = Tuple.to_list(t)
    to_list((add_tag? && ["tuple" | t]) || t, add_tag?)
  end

  def to_list(t, _) do
    t
  end

  @doc """
  将有标记的list转回tuple
  """
  @spec from_list(t :: list) :: any
  def from_list([head | _] = t) when is_list(head) do
    Enum.map(t, &from_list/1)
  end

  def from_list([head | tail] = t) do
    case CommonAPI.to_string(head) do
      "tuple" -> tail |> Enum.map(&from_list(&1)) |> List.to_tuple()
      _ -> t |> Enum.map(&from_list(&1))
    end
  rescue
    error ->
      Logger.warning(
        "#{__MODULE__} from_list failed, error:#{inspect(error)}, stacktrace:#{inspect(__STACKTRACE__)}, t:#{inspect(t)}"
      )

      t |> Enum.map(&from_list(&1))
  end

  def from_list(t) when is_map(t) do
    mod = t |> Map.get(:struct)
    t = t |> Enum.map(fn {k, v} -> {from_list(k), from_list(v)} end) |> Map.new()

    if mod != nil do
      t |> Map.delete(:struct) |> Map.put(:__struct__, mod)
    else
      t
    end
  end

  def from_list(t) do
    t
  end

  @doc """
  atom/integer转字符串
  """
  @spec to_string(t :: atom | integer | tuple | list) :: String.t()
  def to_string(t) when is_atom(t) do
    Atom.to_string(t)
  end

  def to_string(t) when is_integer(t) do
    Integer.to_string(t)
  end

  def to_string(t) when is_tuple(t) do
    t |> CommonAPI.to_list(true) |> CommonAPI.to_string()
  end

  def to_string(t) when is_list(t) do
    t |> Enum.join(",")
  end

  def to_string(t), do: t

  def to_integer(t, default) when is_binary(t) do
    case Integer.parse(t) do
      {i, _} -> i
      _ -> default
    end
  end

  def to_integer(t, _default) when is_integer(t), do: t
  def to_integer(_t, default), do: default

  @doc """
  获取当天凌晨的时间戳
  """
  @spec get_day_0_time() :: integer
  def get_day_0_time() do
    local_time() |> Timex.beginning_of_day() |> Timex.to_unix()
  end

  @doc """
  获取凌晨的时间戳
  """
  @spec get_day_0_time(time :: integer) :: integer
  def get_day_0_time(time) do
    local_time(time) |> Timex.beginning_of_day() |> Timex.to_unix()
  end

  @doc """
  获取当周凌晨的时间戳
  """
  @spec get_week_0_time() :: integer
  def get_week_0_time() do
    local_time() |> Timex.beginning_of_week() |> Timex.to_unix()
  end

  @doc """
  获取周凌晨的时间戳
  """
  @spec get_week_0_time(time :: integer) :: integer
  def get_week_0_time(time) do
    local_time(time) |> Timex.beginning_of_week() |> Timex.to_unix()
  end

  Application.ensure_all_started(:timex)

  @doc """
  获取当前系统时间戳(秒)，受NTP影响
  """
  @spec os_time() :: integer
  def os_time() do
    System.os_time(:second)
  end

  @doc """
  获取当前系统时间戳，受NTP影响

  ## Options
    * :ms - 毫秒
  """
  @spec os_time(:ms) :: integer
  def os_time(:ms) do
    System.os_time(:millisecond)
  end

  @doc """
  获取当前系统时间，受NTP影响
  """
  @spec os_local_time() :: tuple()
  def os_local_time() do
    :calendar.local_time()
  end

  @doc """
  获取当前虚拟机时间戳(秒), 不受NTP影响
  """
  @spec timestamp() :: integer
  def timestamp() do
    offset = Application.get_env(:server, :time_offset, 0)
    System.system_time(:second) + offset
  end

  @doc """
  获取当前虚拟机时间戳, 不受NTP影响

  ## Options
    * :ms - 毫秒
    * time - {{yyyy, m, d}, {h, m, s}}
  """
  @spec timestamp(:ms | (time :: tuple)) :: integer
  def timestamp(:ms) do
    offset = Application.get_env(:server, :time_offset, 0) * 1000
    System.system_time(:millisecond) + offset
  end

  def timestamp({{_, _, _}, {_, _, _}} = time) do
    Timex.to_unix(Timex.to_datetime(time, Timex.local().time_zone))
  end

  @doc """
  当天DateTime
  """
  def local_time() do
    timestamp() |> Timex.from_unix() |> Timex.local()
  end

  @doc """
  获取DateTime
  """
  def local_time(time) do
    time |> Timex.from_unix() |> Timex.local()
  end

  @doc """
  毫秒时间戳转为秒时间戳

  ## Options
    * ms_time - 毫秒时间戳
  """
  @spec ms_to_second(integer) :: integer
  def ms_to_second(ms_time) do
    if ms_time |> Integer.to_string() |> String.length() == 13 do
      div(ms_time, 1000)
    else
      ms_time
    end
  end

  @doc """
  时间戳转时间tuple

  ## Options
    * `timestamp` - 时间戳
  """
  @spec timestamp_to_tuple(timestamp :: integer | nil) ::
          {{yyyy :: integer, m :: integer, d :: integer},
           {h :: integer, m :: integer, s :: integer}}
  def timestamp_to_tuple(timestamp \\ nil) do
    if timestamp != nil do
      timestamp |> Timex.from_unix() |> Timex.local()
    else
      Timex.local()
    end
    |> case do
      %DateTime{
        year: year,
        month: month,
        day: day,
        hour: hour,
        minute: minute,
        second: second
      } ->
        {{year, month, day}, {hour, minute, second}}

      _ ->
        Logger.error("#{__MODULE__} timestamp_to_tuple failed, timestamp:#{inspect(timestamp)}")

        nil
    end
  rescue
    error ->
      Logger.error(
        "#{__MODULE__} timestamp_to_tuple failed, timestamp:#{inspect(timestamp)}, error:#{inspect(error)}, stacktrace:#{inspect(__STACKTRACE__)}"
      )

      nil
  end

  @doc """
  时间戳转时间DateTime

  ## Options
    * `timestamp` - 时间戳
  """
  @spec timestamp_to_datetime(timestamp :: integer) :: DateTime.t()
  def timestamp_to_datetime(timestamp) do
    Timex.to_datetime(Timex.from_unix(timestamp), Timex.local().time_zone)
  end

  @doc """
  时分秒转今日时间戳

  ## Options
    * `str` - 时间字符串，例如"0:00:00"
  """
  def today_string_to_timestamp("0:00:00") do
    local_time() |> Timex.beginning_of_day() |> Timex.to_unix()
  end

  def today_string_to_timestamp(str) do
    [h, min, s] = String.split(str, ":") |> Enum.map(&String.to_integer/1)
    %DateTime{year: y, month: m, day: d} = Timex.local()
    timestamp({{y, m, d}, {h, min, s}})
  end

  @date_string_fomat [:year, :month, :day, :hour, :minute, :second] |> Enum.with_index()

  @doc """
  日期字符串转时间戳, 日期字符串格式: "year-month-day-hour-minute-second"
  """
  @spec ts_from_string(string :: String.t()) :: integer
  def ts_from_string(string) do
    String.split(string, "-") |> to_timestamp
  end

  @doc """
  日期字符串转时间戳, 日期字符串格式: "[year, month, day, hour, minute, second]"
  """
  @spec to_timestamp(list :: list()) :: integer
  def to_timestamp([_year, _month, _day, _hour, _minute, _second] = list) do
    @date_string_fomat
    |> Enum.reduce(local_time(), fn {k, i}, acc ->
      v = list |> Enum.at(i)

      v =
        cond do
          v == nil -> 0
          is_binary(v) -> String.to_integer(v)
          true -> v
        end

      Map.put(acc, k, v)
    end)
    |> Map.put(:microsecond, {0, 0})
    |> Timex.to_unix()
  end

  @doc """
  时间戳转时间字符串, 时间字符串格式: "yyyy-mm-dd HH:MM:SS"
  """
  @spec timestamp_to_str(timestamp :: integer) :: String.t()
  def timestamp_to_str(timestamp) do
    %{year: y, month: mon, day: d, hour: h, minute: m, second: s} =
      timestamp_to_datetime(timestamp)

    [mon, d, h, m, s] =
      [mon, d, h, m, s]
      |> Enum.map(fn t ->
        string = t |> Integer.to_string()
        length = string |> String.length()

        case length do
          1 -> "0" <> string
          _ -> string
        end
      end)

    "#{y}-#{mon}-#{d} #{h}:#{m}:#{s}"
  end

  @doc """
  获得时间是一周第几天(1-7，1是周一)
  """
  @spec day_of_week() :: integer
  def day_of_week() do
    day_of_week(local_time())
  end

  @spec day_of_week(timestamp :: integer) :: integer
  def day_of_week(timestamp) when is_integer(timestamp) do
    timestamp |> Timex.from_unix() |> Timex.local() |> Timex.weekday()
  end

  @spec day_of_week(time :: DateTime.t()) :: integer
  def day_of_week(local_time) do
    Timex.weekday(local_time)
  end

  @seonds_hour 60 * 60
  @seonds_one_day 24 * @seonds_hour

  @doc """
  本周一0点到参数时间已过的秒数

  ## Options
    * `week_day` - 周几，1-7
    * `hours` - 时
    * `minutes` - 分
    * `seconds` - 秒
  """
  @spec seconds_from_monday(
          week_day :: integer,
          hours :: integer,
          minutes :: integer,
          seconds :: integer
        ) :: integer
  def seconds_from_monday(week_day, hours, minutes, seconds \\ 0) do
    (week_day - 1) * @seonds_one_day + hours * @seonds_hour + minutes * 60 + seconds
  end

  @doc """
  本周一0点到现在已过的秒数
  """
  @spec seconds_from_monday() :: integer
  def seconds_from_monday() do
    now = local_time()
    Timex.diff(now, Timex.beginning_of_week(now, :mon), :seconds)
  end

  @doc """
  今日0点到参数时间已过的秒数
  """
  @spec seconds_from_am0(hours :: integer, minutes :: integer, seconds :: integer) :: integer
  def seconds_from_am0(hours, minutes, seconds \\ 0) do
    hours * @seonds_hour + minutes * 60 + seconds
  end

  @doc """
  今日0点到现在已过的秒数
  """
  @spec seconds_from_am0() :: integer
  def seconds_from_am0() do
    date = local_time()
    date_am0 = date |> Timex.beginning_of_day()
    Timex.diff(date, date_am0, :seconds)
  end

  @doc """
  比较两个时间戳是否为不同天
  """
  @spec is_diff_day?(timestamp1 :: integer, timestamp2 :: integer, offset :: integer) :: boolean
  def is_diff_day?(timestamp1, timestamp2, offset \\ 0) do
    diff_days(timestamp1 + offset, timestamp2 + offset) != 0
  end

  @doc """
  比较两个时间戳是否为不同周
  """
  @spec is_diff_week?(timestamp1 :: integer, timestamp2 :: integer, offset :: integer) :: boolean
  def is_diff_week?(timestamp1, timestamp2, offset \\ 0) do
    diff_weeks(timestamp1 + offset, timestamp2 + offset) != 0
  end

  @doc """
  比较两个时间戳是否为不同月
  """
  @spec is_diff_month?(timestamp1 :: integer, timestamp2 :: integer, offset :: integer) :: boolean
  def is_diff_month?(timestamp1, timestamp2, offset \\ 0) do
    diff_months(timestamp1 + offset, timestamp2 + offset) != 0
  end

  @doc """
  比较两个时间戳是否为不同年
  """
  @spec is_diff_year?(timestamp1 :: integer, timestamp2 :: integer, offset :: integer) :: boolean
  def is_diff_year?(timestamp1, timestamp2, offset \\ 0) do
    diff_years(timestamp1 + offset, timestamp2 + offset) != 0
  end

  @doc """
  构造格式串子串列表

  ## Examples

    iex> CommonAPI.format_make_fmt_list("恭喜{0}创建{1}军团")
    ["恭喜", "创建", "军团"]

  """
  @spec format_make_fmt_list(format_str :: String.t()) :: list
  def format_make_fmt_list(format_str) when is_binary(format_str) do
    format_str |> String.split(~r"\{[0-9]\}")
  end

  @doc """
  先构造格式串子串列表, 然后使用格式串依次插入参数组成字符串

  ## Examples

    iex> CommonAPI.format_string("恭喜{0}创建{1}军团", ["zhangsan", "lisi"])
    "恭喜zhangsan创建lisi军团"
    iex> CommonAPI.format_string("{0} {1} * * {2} *", [0, 5, 1])
    "0 5 * * 1 *"

  """
  @spec format_string(format_str :: String.t(), param_list :: list) :: String.t()
  def format_string(format_str, param_list) when is_binary(format_str) do
    format_str |> String.split(~r"\{[0-9]\}") |> format_string(param_list)
  end

  @spec format_string(str_list :: list, param_list :: list) :: String.t()
  def format_string(str_list, param_list) when is_list(str_list) do
    {result_list, _} =
      str_list
      |> Enum.reduce({[], param_list}, fn str_item, {lst, param_list} ->
        case param_list do
          [param | param_list] ->
            {[str_item | lst] |> (fn lst -> [Kernel.to_string(param) | lst] end).(), param_list}

          _ ->
            {[str_item | lst], param_list}
        end
      end)

    List.to_string(Enum.reverse(result_list))
  end

  @doc """
  比较两个时间戳相差天数, t1 - t2
  """
  @spec diff_days(timestamp1 :: integer, timestamp2 :: integer) :: integer
  def diff_days(t1, t2) do
    cond do
      t1 > t2 -> div(t1 - @zero_day_time, @day_sec) - div(t2 - @zero_day_time, @day_sec)
      t1 < t2 -> div(t2 - @zero_day_time, @day_sec) - div(t1 - @zero_day_time, @day_sec)
      true -> 0
    end
  end

  @doc """
  比较两个时间戳相差周数, t1 - t2
  """
  @spec diff_weeks(timestamp1 :: integer, timestamp2 :: integer) :: integer
  def diff_weeks(t1, t2) do
    cond do
      t1 > t2 -> div(t1 - @zero_week_time, @week_sec) - div(t2 - @zero_week_time, @week_sec)
      t1 < t2 -> div(t2 - @zero_week_time, @week_sec) - div(t1 - @zero_week_time, @week_sec)
      true -> 0
    end
  end

  @doc """
  比较两个时间戳相差月数, t1 - t2
  """
  @spec diff_months(timestamp1 :: integer, timestamp2 :: integer) :: integer
  def diff_months(t1, t2) do
    if t1 != t2 do
      %{year: y1, month: m1} = timestamp_to_datetime(t1)
      %{year: y2, month: m2} = timestamp_to_datetime(t2)

      if t1 > t2 do
        (y1 - y2) * 12 + m1 - m2
      else
        (y2 - y1) * 12 + m2 - m1
      end
    else
      0
    end
  end

  @doc """
  比较两个时间戳相差年数, t1 - t2
  """
  @spec diff_years(timestamp1 :: integer, timestamp2 :: integer) :: integer
  def diff_years(t1, t2) do
    if t1 != t2 do
      %{year: y1} = timestamp_to_datetime(t1)
      %{year: y2} = timestamp_to_datetime(t2)

      if t1 > t2 do
        y1 - y2
      else
        y2 - y1
      end
    else
      0
    end
  end

  @doc """
  在时间戳的基础上增加/减少天数的0点时间戳
  """
  @spec get_offset_day_0_time(timestamp :: integer, offset :: integer) :: integer
  def get_offset_day_0_time(timestamp, offset \\ 0) do
    timestamp_to_datetime(timestamp + offset * @day_sec)
    |> Timex.beginning_of_day()
    |> Timex.to_unix()
  end

  @doc """
  在时间戳的基础上增加/减少月数的0点时间戳
  """
  def get_offset_month_0_time(timestamp, offset \\ 0) do
    beginning_ts =
      timestamp |> timestamp_to_datetime |> Timex.beginning_of_month() |> Timex.to_unix()

    (beginning_ts + offset * 31 * @day_sec)
    |> timestamp_to_datetime
    |> Timex.beginning_of_month()
    |> Timex.to_unix()
  end

  @doc """
  去除特殊字符, 只保留中文, 字母, 数字
  """
  @spec strip(str :: String.t()) :: String.t()
  def strip(str) do
    {:ok, r} = Regex.compile("[^a-zA-Z0-9\u4e00-\u9fa5]")
    Regex.replace(r, str, "")
  end

  @doc """
  执行函数
  """
  @spec do_func(mod :: atom, func :: atom, args :: list, default :: any) :: any
  def do_func(mod, func, args \\ [], default \\ nil) do
    if mod != nil do
      mod = (is_binary(mod) && Module.concat(:"Elixir", Macro.camelize(mod))) || mod
      args = List.wrap(args)
      arity = length(args)

      with true <- is_atom(func),
           CommonAPI.Macro.ensure_module(mod),
           true <- function_exported?(mod, func, arity) do
        apply(mod, func, args)
      else
        _ ->
          Logger.warning("do_func [#{mod}:#{func}/#{arity}] fail, func not existed")
          default
      end
    else
      Logger.warning("do_func [#{mod}:#{func}] fail, mod incorrect")
      default
    end
  rescue
    error ->
      Logger.warning(
        "#{__MODULE__} do_func [#{mod}:#{func}] failed, error:#{inspect(error)}, stacktrace:#{inspect(__STACKTRACE__)}, args:#{inspect(args)}"
      )

      default
  end

  @doc """
  执行函数
  """
  @spec do_anon_func(func :: fun(), args :: list, default :: any) :: any
  def do_anon_func(func, args \\ [], default \\ nil) do
    args = List.wrap(args)

    if is_function(func) do
      apply(func, args)
    else
      Logger.warning(
        "#{__MODULE__} do_anon_func func failed, func not existed, func:#{inspect(func)}, args:#{inspect(args)}"
      )

      default
    end
  rescue
    error ->
      Logger.warning(
        "#{__MODULE__} do_anon_func func failed, error:#{inspect(error)}, stacktrace:#{inspect(__STACKTRACE__)}, func:#{inspect(func)}, args:#{inspect(args)}"
      )

      default
  end

  @doc """
  查询函数是否存在
  """
  @spec func_exist?(mod :: atom, func :: atom, arity :: integer) :: any
  def func_exist?(mod, func, arity) do
    if is_atom(mod) and is_atom(func) and is_integer(arity) do
      CommonAPI.Macro.ensure_module(mod)
      function_exported?(mod, func, arity)
    else
      false
    end
  end

  @doc """
  字符串转atom
  """
  @spec to_atom_key(config :: map | list | any) :: map | list | any
  def to_atom_key(config) when is_map(config) do
    config
    |> Map.new(fn {k, v} ->
      {parse_key_to_atom(k), to_atom_key(v)}
    end)
  end

  def to_atom_key(config) when is_list(config) do
    Enum.map(config, &to_atom_key(&1))
  end

  def to_atom_key(config) do
    config
  end

  @doc """
  指定将map的key转成atom
  """
  @spec to_atom_val(data :: map, keys :: atom | [atom, ...]) :: map
  def to_atom_val(data, keys) when is_map(data) and is_list(keys) do
    keys
    |> Enum.reduce(data, fn key, data ->
      if Map.has_key?(data, key) do
        to_atom_val(data, key)
      else
        data
      end
    end)
  end

  def to_atom_val(data, key) when is_map(data) and is_atom(key) do
    data
    |> Map.update!(key, fn val ->
      if is_atom(val) do
        val
      else
        CommonAPI.to_atom(val)
      end
    end)
  end

  def to_atom_val(data, _key) do
    data
  end

  @spec parse_key_to_atom(key :: String.t()) :: atom
  def parse_key_to_atom(key) when is_binary(key) do
    case Integer.parse(key) do
      {k1, _} ->
        k1

      _ ->
        if String.match?(key, ~r/^tuple,/) do
          String.split(key, ",") |> Enum.map(&parse_key_to_atom(&1)) |> CommonAPI.from_list()
        else
          CommonAPI.to_atom(key)
        end
    end
  end

  def parse_key_to_atom(key) do
    key
  end

  @doc """
  将map的key转成字符串
  """
  @spec key_to_string(t :: map) :: map
  def key_to_string(t) when is_map(t) do
    t
    |> Enum.map(fn {k, v} ->
      {CommonAPI.to_string(k), key_to_string(v)}
    end)
    |> Map.new()
  rescue
    error ->
      Logger.warning(
        "#{__MODULE__} key_to_string failed, error:#{inspect(error)}, stacktrace:#{inspect(__STACKTRACE__)}, t:#{inspect(t)}"
      )

      t
  end

  def key_to_string(t) when is_list(t) do
    t |> Enum.map(&key_to_string(&1))
  end

  def key_to_string(t) do
    t
  end

  @doc """
  二进制转其他格式
  """
  @spec binary_to_term(binary :: binary) :: term
  def binary_to_term(binary) do
    :erlang.binary_to_term(binary, [:safe])
  rescue
    ArgumentError ->
      try do
        :erlang.binary_to_term(binary)
      rescue
        error ->
          Logger.warning(
            "#{__MODULE__} binary_to_term error:#{inspect(error)}, stacktrace:#{inspect(__STACKTRACE__)}, binary:#{inspect(binary)}"
          )

          nil
      end

    error ->
      Logger.warning(
        "#{__MODULE__} binary_to_term error:#{inspect(error)}, stacktrace:#{inspect(__STACKTRACE__)}, binary:#{inspect(binary)}"
      )

      nil
  end

  @doc """
  添加process timer
  """
  @spec add_process_timer(key :: any, msg :: any, end_ms_time :: integer, flag :: any) :: :ok
  def add_process_timer(key, msg, end_ms_time, flag \\ nil) do
    now_ms_time = CommonAPI.timestamp(:ms)

    if end_ms_time <= now_ms_time do
      Process.send(self(), msg, [])
      :failed
    else
      case Process.get(:timers, %{}) do
        %{^key => {ref, time, _}} = data ->
          timer_res = Process.read_timer(ref)

          if end_ms_time < time || time < now_ms_time || timer_res == false do
            timer_res != false && Process.cancel_timer(ref)
            new_ref = Process.send_after(self(), msg, max(end_ms_time - now_ms_time, 0))
            Process.put(:timers, data |> Map.put(key, {new_ref, end_ms_time, flag}))
            :ok
          else
            :failed
          end

        data ->
          new_ref = Process.send_after(self(), msg, max(end_ms_time - now_ms_time, 0))
          Process.put(:timers, data |> Map.put(key, {new_ref, end_ms_time, flag}))
          :ok
      end
    end
  end

  @doc """
  删除process timer
  """
  @spec del_process_timer(key :: any, flag :: any) :: :ok
  def del_process_timer(key, flag) do
    case Process.get(:timers, %{}) do
      %{^key => {ref, _time, ^flag}} = data ->
        Process.read_timer(ref) != false && Process.cancel_timer(ref)
        Process.put(:timers, data |> Map.delete(key))
        :ok

      _ ->
        :failed
    end
  end

  @doc """
  删除process timer
  """
  @spec del_process_timer(key :: any) :: :ok
  def del_process_timer(key) do
    case Process.get(:timers, %{}) do
      %{^key => {ref, _time, _}} = data ->
        Process.read_timer(ref) != false && Process.cancel_timer(ref)
        Process.put(:timers, data |> Map.delete(key))

      _ ->
        :ok
    end
  end

  @doc """
  查看process timers
  """
  @spec process_timers() :: map
  def process_timers() do
    Process.get(:timers, %{})
  end

  @doc """
  查询process timer是否存在
  """
  @spec process_timer_exist?(key :: any) :: boolean()
  def process_timer_exist?(key) do
    process_timers() |> Map.has_key?(key)
  end

  @doc """
  添加process record ts
  """
  @spec add_process_record_ts(key :: any, msg :: any, new_ms_time :: integer, flag :: any) :: :ok
  def add_process_record_ts(key, msg, new_ms_time, flag \\ nil) do
    now_ms_time = CommonAPI.timestamp(:ms)

    case Process.get(:record_ts, %{}) do
      %{^key => {_prev_msg, prev_time, _prev_flag}} = data ->
        cond do
          prev_time <= now_ms_time or new_ms_time <= now_ms_time ->
            Process.send_after(self(), msg, 0)
            Process.put(:record_ts, data |> Map.delete(key))
            :ok

          new_ms_time > now_ms_time ->
            Process.put(
              :record_ts,
              data |> Map.put(key, {msg, min(new_ms_time, prev_time), flag})
            )

            :ok

          true ->
            :failed
        end

      data ->
        Process.put(:record_ts, data |> Map.put(key, {msg, new_ms_time, flag}))
        :ok
    end
  end

  @doc """
  删除process record ts
  """
  @spec del_process_record_ts(key :: any, flag :: any) :: :ok
  def del_process_record_ts(key, flag) do
    case Process.get(:record_ts, %{}) do
      %{^key => {_prev_msg, _prev_time, ^flag}} = data ->
        Process.put(:record_ts, data |> Map.delete(key))
        :ok

      _ ->
        :failed
    end
  end

  @doc """
  删除process record ts
  """
  @spec del_process_record_ts(key :: any) :: :ok
  def del_process_record_ts(key) do
    case Process.get(:record_ts, %{}) do
      %{^key => {_prev_msg, _prev_time, _flag}} = data ->
        Process.put(:record_ts, data |> Map.delete(key))

      _ ->
        :ok
    end
  end

  @doc """
  查找DynamicSupervisor的children process并发消息
  """
  def broadcast_children({_id, pid, :supervisor, _modules}, msg) do
    broadcast_children(pid, msg)
  end

  def broadcast_children({_id, pid, :worker, _modules}, msg) do
    GenServer.cast(pid, msg)
  end

  def broadcast_children({_id, _pid, _type, _modules}, _msg) do
    :ok
  end

  def broadcast_children([], _msg) do
    :ok
  end

  def broadcast_children([_ | _] = list, msg) do
    list |> Enum.each(&broadcast_children(&1, msg))
  end

  def broadcast_children(supervisor, msg) do
    DynamicSupervisor.which_children(supervisor) |> Enum.each(&broadcast_children(&1, msg))
  end

  @doc """
  获取supervisor子进程列表
  """
  def supervisor_childrens(supervisor, mod) do
    Supervisor.which_children(supervisor)
    |> find_children(DynamicSupervisor, :supervisor)
    |> find_children(mod, :worker)
  end

  defp find_children(list, mod, type) do
    list
    |> Enum.flat_map(fn t ->
      if elem(t, 3) == [mod] and elem(t, 2) == type do
        if type == :supervisor do
          elem(t, 1) |> Supervisor.which_children()
        else
          [elem(t, 1)]
        end
      else
        []
      end
    end)
  end

  @doc """
  加载目录下的beam文件
  """
  def load_third_beams(dir) do
    case File.ls(dir) do
      {:ok, files} ->
        files
        |> Enum.each(fn name ->
          if not File.dir?(name) do
            Path.basename(name, ".beam") |> CommonAPI.to_atom() |> :code.load_file()
          end
        end)

      _ ->
        :ok
    end
  end

  @doc """
  生成token
  """
  def make_token(key, str, expire_time) do
    expire_time = Integer.to_string(expire_time)

    (:crypto.hash(:md5, key <> expire_time <> str) <> expire_time)
    |> Base.encode64(case: :lower)
  rescue
    error ->
      Logger.warning(
        "#{__MODULE__} make_token failed, error:#{inspect(error)}, stacktrace:#{inspect(__STACKTRACE__)}, str:#{inspect(str)}"
      )

      nil
  end

  @doc """
  验证token
  """
  def token_verify?(token, key, str) do
    with {:ok, <<md5::binary-size(16), time::binary>>} <- Base.decode64(token),
         {expire_time, ""} <- Integer.parse(time) do
      CommonAPI.os_time() <= expire_time && :crypto.hash(:md5, key <> time <> str) == md5
    else
      _ ->
        false
    end
  rescue
    error ->
      Logger.warning(
        "#{__MODULE__} token_verify? failed, error:#{inspect(error)}, stacktrace:#{inspect(__STACKTRACE__)}, str:#{inspect(str)}"
      )

      false
  end

  def win32?() do
    case :os.type() do
      {:win32, _} -> true
      _ -> false
    end
  end

  @doc """
  是否含有中文
  """
  @chinese_regex Regex.compile!("[\u4e00-\u9fa5]")
  def has_chinese?(str) do
    Regex.match?(@chinese_regex, str)
  end

  @doc """
  含有中文字符的数量
  """
  def chinese_chars_count(str) do
    case Regex.scan(@chinese_regex, str) do
      [] -> 0
      [_ | _] = list -> div(length(list), 3)
    end
  end

  @doc """
  计算字符数，中文算2个，其他算1个
  """
  def chars_count(str) do
    chinese_chars_count = chinese_chars_count(str)

    if chinese_chars_count > 0 do
      String.length(str) + chinese_chars_count
    else
      String.length(str)
    end
  end

  @doc """
  版本号对比
  """
  def version_compare(version1, version2) when is_binary(version1) and is_binary(version2) do
    id1 = calc_version(version1)
    id2 = calc_version(version2)

    cond do
      id1 == -1 or id2 == -1 -> :error
      id1 > id2 -> :gt
      id1 < id2 -> :lt
      true -> :eq
    end
  end

  def version_compare(version1, version2) do
    Logger.error(
      "#{__MODULE__} version_compare failed, version1:#{inspect(version1)}, version2:#{inspect(version2)}"
    )

    :error
  end

  defp calc_version(version) when is_binary(version) do
    String.split(version, ".")
    |> Enum.reverse()
    |> Enum.reduce({0, 1}, fn t, {total, coe} ->
      {total + CommonAPI.to_integer(t, 0) * coe, coe * 1000}
    end)
    |> elem(0)
  rescue
    error ->
      Logger.error(
        "#{__MODULE__} calc_version failed, error:#{inspect(error)}, stacktrace:#{inspect(__STACKTRACE__)}, version:#{inspect(version)}"
      )

      -1
  end

  defp calc_version(version) do
    Logger.error("#{__MODULE__} calc_version failed, version:#{inspect(version)}")
    -1
  end

  @doc """
  版本号匹配
  """
  @requirements %{
    ">" => [:gt],
    "<" => [:lt],
    "==" => [:eq],
    ">=" => [:gt, :eq],
    "<=" => [:lt, :eq]
  }

  def version_match?(version1, requirement, version2) do
    case Map.get(@requirements, requirement) do
      [_ | _] = requirements ->
        version_compare(version1, version2) in requirements

      _ ->
        false
    end
  end

  @doc """
  创建热更目录和文件列表
  """
  def create_hotfix(name, beams) when is_binary(beams) do
    create_hotfix(name, String.split(beams, ","))
  end

  def create_hotfix(name, beams) do
    path_list =
      beams
      |> List.wrap()
      |> Enum.flat_map(fn beam ->
        module =
          if is_binary(beam) do
            Module.concat(:"Elixir", Macro.camelize(String.trim(beam)))
          else
            beam
          end

        beam_name = Atom.to_string(module) |> String.split("Elixir.") |> Enum.at(-1)

        case :code.which(module) do
          :non_existing ->
            []

          file ->
            path = Path.relative_to_cwd(file)
            File.write!("hotfix.txt", beam_name <> "\n", [:append])
            [path]
        end
      end)
      |> IO.inspect()

    {{year, month, day}, {h, m, s}} = CommonAPI.os_local_time()

    time_str =
      [year, month, day, h, m, s]
      |> Enum.reduce("", fn t, acc ->
        if t < 10 do
          acc <> "0" <> CommonAPI.to_string(t)
        else
          acc <> CommonAPI.to_string(t)
        end
      end)

    tar_name = "#{name}-patch-#{time_str}.tar.gz"

    :erl_tar.create(
      String.to_charlist(tar_name),
      (path_list ++ ["hotfix.txt"]) |> Enum.map(&String.to_charlist/1)
    )

    IO.inspect(tar_name)
  end

  @doc """
  根据热更文件列表更新
  """
  def run_hotfix(tar_path) do
    case :erl_tar.extract(tar_path) do
      :ok ->
        case File.read("hotfix.txt") do
          {:ok, s} ->
            String.split(s, "\n")
            |> Enum.flat_map(fn mod_str ->
              if mod_str != "" do
                mod = Module.concat(:"Elixir", Macro.camelize(mod_str))
                :code.purge(mod)
                [mod]
              else
                []
              end
            end)
            |> case do
              [_ | _] = modules ->
                case :code.atomic_load(modules) do
                  :ok ->
                    Logger.info("run_hotfix success, modules:#{inspect(modules)}")
                    IO.inspect(modules)
                    :ok

                  error ->
                    Logger.error("run_hotfix failed, error:#{inspect(error)}")
                    error
                end

              _ ->
                Logger.error("run_hotfix failed, no module")
                :failed
            end

          _ ->
            Logger.error("run_hotfix failed, hotfix.txt not found")
            :failed
        end

      _ ->
        Logger.error("run_hotfix failed, #{tar_path} not found")
        :failed
    end
  end

  def hotfix_test() do
    Logger.info("#{__MODULE__} hotfix_test ok")
    :ok
  end

  @doc """
  查询进程消息队列数量
  """
  def message_queue_len(nil) do
    0
  end

  def message_queue_len(pid) when is_pid(pid) do
    case Process.info(pid, :message_queue_len) do
      {:message_queue_len, num} -> num
      _ -> 0
    end
  rescue
    _ -> 0
  end

  def message_queue_len(name) when is_atom(name) do
    message_queue_len(Process.whereis(name))
  end

  def message_queue_len(name) when is_binary(name) do
    message_queue_len(CommonAPI.to_atom(name))
  end

  def message_queue_len(_name) do
    0
  end

  @doc """
  执行指定模块，指定函数
  """
  def dispatch(module, action, args) do
    mod = Module.concat(:"Elixir", Macro.camelize(Atom.to_string(module)))
    func = action
    len = length(args)

    CommonAPI.Macro.ensure_module(mod)

    if function_exported?(mod, func, len) do
      apply(mod, func, args)
    else
      Logger.warning("#{module}:#{action}/#{len} not exist")
    end
  rescue
    error ->
      Logger.warning(
        "#{module}:#{action} error:#{inspect(error)}, stacktrace:#{inspect(__STACKTRACE__)}"
      )
  end
end
