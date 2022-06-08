defmodule GameDef do
  require Utils
  require Logger
  # @base_url Application.get_env(:pressure_test, :config_base_url)

  defmacro __using__(_) do
    HTTPoison.start()
  end

  defmacro config(mod, options) do
    quote do
      defmodule unquote(mod) do
        use GameDef
        GameDef.defconf unquote(options)
      end
    end
  end

  defmacro defconst([path: path, getter: getter]) do
    config = load_const(path) |> to_atom_key

    quote do
      def unquote(getter)() do
        unquote(Macro.escape(config))
      end
    end
  end

  defmacro defconf(options) do
    transform = get_transform(options)

    Keyword.get(options, :view)
    |> load_rows
    |> Enum.map(&(make_getter(&1["key"], transform.(&1["value"]), options)))
  end

  def config_url(view) do
    [design, view] = String.split(view, "/")
    Application.get_env(:pressure_test, :config_base_url) <> "_design/#{design}/_view/#{view}"
  end

  def load_rows(view) do
    [design, v] = String.split(view, "/")
    path = "#{design}-#{v}"
    config_url(view)
    |> load_config(path)
    |> Map.get("rows")
  end

  def load_const(path) do
    {path, p} =
      case String.split(path, "/") do
        [p] -> {p, p}
        [design, show, doc] -> {"_design/#{design}/_show/#{show}/#{doc}", "#{design}-#{show}-#{doc}"}
      end

    config = load_config(Application.get_env(:pressure_test, :config_base_url) <> path, p)

    # get config from value field, or use whole map
    config |> Map.get("value", config)
  end

  def load_config(config_url) do
    [design, view] = String.split(config_url, "/")
    path = "#{design}-#{view}"
    load_config(config_url, path)
  end

  def load_config(config_url, path) do
    base_path = "./lib/json_local/"
    if not File.exists?(base_path) do
      File.mkdir_p(base_path)
    end
    paaa = base_path <> path <>".json"
    with {:ok, response} <- HTTPoison.get(config_url, [], hackney: [pool: :default]),
      true <- (not File.exists?(paaa)) || Application.get_env(:pressure_test, :load_config, false)
    do
      json = Map.get(response, :body)
      paaa |> IO.inspect
      File.write(paaa, json, [:write])
    end
    File.read(paaa)
    |> elem(1)
    |> Jason.decode!
  end

  def to_atom_key(config) when is_map(config) do
    config |> Map.new(fn {k, v} -> {Utils.to_atom(k), to_atom_key(v)} end)
  end

  def to_atom_key(config) do
    config
  end

  def to_tagged_tuple([h | t]) when is_binary(h) do
    [Utils.to_atom(h) | t] |> List.to_tuple
  end

  def to_tagged_tuple([h | _] = list) when is_atom(h) do
    list |> List.to_tuple
  end

  def to_tagged_tuples(list) do
    list |> Enum.map(&to_tagged_tuple/1)
  end

  def get_response_reply(msg) do
    post_msg = 
    %{
      "reqType" => 0,
      "perception" => %{
        "inputText" => %{
            "text" => msg
        }
      },
      "userInfo" => %{
          "apiKey" =>  Application.get_env(:pressure_test, :api_key),
          "userId" => Application.get_env(:pressure_test, :user_id)
      }
    } 
    |> ExchangeCode.encode
    Application.get_env(:pressure_test, :response_reply_url)
    |> HTTPoison.post!(post_msg)
    # |> #IO.inspect
    |> Map.get(:body)
    |> Poison.decode!
    |> Map.get("results")
  end

  defp get_transform(options) do
    if Keyword.has_key?(options, :transform) do
      Keyword.get(options, :transform)
      |> Code.eval_quoted([], __ENV__)
      |> elem(0)
    else
      &to_atom_key/1
    end
  end

  defp make_getter(key, value, options) when is_map(value) do
    mod = Keyword.get(options, :as)
    config = if mod != nil, do: struct(Macro.expand(mod, __ENV__), value), else: value
    getter = Keyword.get(options, :getter, :get)

    quote do
      def unquote(getter)(unquote_splicing(List.wrap(key))) do
        unquote(Macro.escape(config))
      end
    end
  end

  defp make_getter(key, value, options) do
    getter = Keyword.get(options, :getter, :get)
    quote do
      def unquote(getter)(unquote_splicing(List.wrap(key))) do
        unquote(Macro.escape(value))
      end
    end
  end
end
