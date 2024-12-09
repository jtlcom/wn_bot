defmodule Utils do
  defmacro to_atom(string) do
    if Mix.env() == :dev do
      quote do: String.to_atom(unquote(string))
    else
      quote do: String.to_atom(unquote(string))
    end
  end

  defmacro ensure_module(mod) do
    if Mix.env() == :dev do
      quote do: Code.ensure_loaded(unquote(mod))
    end
  end

  def to_tuple(list) when is_list(list) do
    List.to_tuple(list)
  end

  def to_tuple(tuple) when is_tuple(tuple) do
    tuple
  end

  def to_string(atom) when is_atom(atom) do
    Atom.to_string(atom)
  end

  def to_string(int) when is_integer(int) do
    Integer.to_string(int)
  end

  ## 当天凌晨的时间戳
  def get_day_0_time() do
    Timex.local() |> Timex.beginning_of_day() |> Timex.to_unix()
  end

  # ---------------------------------------------------------------------
  # UTC时间戳(秒)
  # @local_zone Timex.local().time_zone
  def timestamp() do
    System.system_time(:second)
  end

  def timestamp(:ms) do
    System.system_time(:millisecond)
  end

  # 时间转时间戳，格式：{{2013,11,13}, {18,0,0}}
  def timestamp(date_time) do
    Timex.to_unix(Timex.to_datetime(date_time, "Etc/UTC"))
  end

  # 时间戳转时间
  def timestamp_to_datetime(time_stamp) do
    Timex.to_datetime(Timex.from_unix(time_stamp), Timex.local().time_zone)
  end

  # ---------------------------------------------------------------------
  # Week day
  @seonds_hour 60 * 60
  @seonds_one_day 24 * @seonds_hour
  def day_of_week() do
    day_of_week(Timex.local())
  end

  def day_of_week(local_time) do
    Timex.weekday(local_time)
  end

  # 从周一0点至今
  def seconds_from_monday(week_day, hours, minutes, seconds \\ 0) do
    (week_day - 1) * @seonds_one_day + hours * @seonds_hour + minutes * 60 + seconds
  end

  def seconds_from_monday() do
    now = Timex.local()
    Timex.diff(now, Timex.beginning_of_week(now, :mon), :seconds)
  end

  # 从本日0点至今
  def seconds_from_am0(hours, minutes, seconds \\ 0) do
    hours * @seonds_hour + minutes * 60 + seconds
  end

  def seconds_from_am0() do
    date = Timex.local()
    date_am0 = date |> Timex.beginning_of_day()
    Timex.diff(date, date_am0, :seconds)
  end

  # ---------------------------------------------------------------------
  # 处理C#模式文字格式化, 目前默认按顺序处理参数列表, 参数必须可转换为字符串
  # 若存在乱序填充且需精确匹配, 将使用reduce与slice截取生成子串列表与索引列表

  # 构造格式串子串列表
  def format_make_fmt_list(format_str) when is_binary(format_str) do
    format_str |> String.split(~r"\{[0-9]\}")
  end

  # 使用格式串依次插入参数
  def format_string(format_str, param_list) when is_binary(format_str) do
    format_str |> String.split(~r"\{[0-9]\}") |> format_string(param_list)
  end

  # 使用子串列表依次插入参数
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

  def get_now_ts_data(ts \\ Utils.timestamp()) do
    get_now_tms_data(ts * 1000)
  end

  def get_now_tms_data(ts \\ Utils.timestamp(:ms)) do
    {ts, timestamp_to_datetime(div(ts, 1000)) |> Date.to_string()}
  end

  def ts_to_format(ts \\ Utils.timestamp(), without_s \\ true)

  def ts_to_format(ts, without_s) do
    # "%F_%T"
    format_str =
      (not without_s && "{YYYY}-{0M}-{0D}_{h24}{m}{s}") || "{YYYY}-{0M}-{0D}_{h24}{m}00"

    tmx = timestamp_to_datetime(ts)

    tmx
    |> Timex.format!(format_str)

    # Timex.format!(tmx, "%F", :strftime) <> "_" <> (Timex.format!(tmx, "%T", :strftime) |> String.split(":") |> Enum.join())
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
end
