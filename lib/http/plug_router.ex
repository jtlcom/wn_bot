defmodule PlugRouter do
  import Plug.Conn
  use Plug.Router
  require Logger
  require Utils

  plug :match
  plug :dispatch

  get "/" do
    html = Lala.generate_html()
    send_resp(conn, 200, html)
  end



  get "/baidu" do
    html = Baidu.generate_html()
    send_resp(conn, 200, html)
  end

  get "/test" do
    send_resp(conn, 200, "this is test!!!")
  end

  # get("/test/:name", do: send_resp(conn, 200, "hello, #{name}"))

  # get "/paras" do
  #   body_params = conn.body_params
  #   Logger.debug("params is #{inspect(body_params)}")
  #   send_resp(conn, 200, "this is paras")
  # end

  # get "/reload/:mods" do
  #   result =
  #     cond do
  #       String.length(mods) > 0 ->
  #         res =
  #           String.split(mods, ":")
  #           |> load_mods
  #           |> Enum.reject(&Enum.member?(&1, true))

  #         case res do
  #           res when length(res) > 0 ->
  #             Enum.reduce(res, "", fn [mod, false, reason], acc ->
  #               acc <> "[#{mod}] error: " <> reason <> "\n"
  #             end)

  #           _ ->
  #             "ok"
  #         end

  #       true ->
  #         "unsupport params"
  #     end

  #   send_resp(conn, 200, result)
  # end

  # @err_idip_and_game_svr_network -101
  # @err_game_svr_internal -102

  # post "/idip" do
  #   # Logger.debug("conn is #{inspect(conn, pretty: true)}")

  #   length =
  #     conn.req_headers |> Map.new() |> Map.get("content-length", "0") |> String.to_integer()

  #   case Plug.Conn.read_body(conn, length: length) do
  #     {:ok, body, conn} ->
  #       Logger.debug("idip request body: #{inspect(body, pretty: true)}")

  #       try do
  #         {stat, res} = Idip.analyze(body)

  #         Logger.debug("idip stat: #{stat}, res: #{inspect(res, pretty: true)}")
  #         send_resp(conn, 200, %{stat: stat, res: res} |> Jason.encode!())
  #       rescue
  #         err ->
  #           Logger.warn(fn ->
  #             "idip err: #{inspect(err, pretty: true)}, body: #{inspect(body, pretty: true)}, stacktrace is #{
  #               inspect(:erlang.get_stacktrace(), pretty: true)
  #             }"
  #           end)

  #           send_resp(conn, 200, %{stat: :error, res: @err_game_svr_internal} |> Jason.encode!())
  #       end

  #     {:error, error} ->
  #       Logger.warn("idip error: #{inspect(error, pretty: true)}")

  #       send_resp(
  #         conn,
  #         200,
  #         %{stat: :error, res: @err_idip_and_game_svr_network} |> Jason.encode!()
  #       )
  #   end
  # end

  # @err_payflow_internal 1100
  # @err_payflow_networkd 1101

  # post "/payflow" do
  #   # Logger.debug("conn is #{inspect(conn, pretty: true)}")

  #   length =
  #     conn.req_headers |> Map.new() |> Map.get("content-length", "0") |> String.to_integer()

  #   case Plug.Conn.read_body(conn, length: length) do
  #     {:ok, body, conn} ->
  #       Logger.debug("payflow request body: #{inspect(body, pretty: true)}")

  #       try do
  #         {stat, res} = PayFlow.analyze(body)

  #         Logger.debug("payflow stat: #{stat}, res: #{inspect(res, pretty: true)}")
  #         send_resp(conn, 200, %{stat: stat, res: res} |> Jason.encode!())
  #       rescue
  #         err ->
  #           Logger.warn(fn ->
  #             "payflow err: #{inspect(err, pretty: true)}, body: #{inspect(body, pretty: true)}, stacktrace is #{
  #               inspect(:erlang.get_stacktrace(), pretty: true)
  #             }"
  #           end)

  #           send_resp(
  #             conn,
  #             200,
  #             %{stat: @err_payflow_internal, res: "my server internal error"} |> Jason.encode!()
  #           )
  #       end

  #     {:error, error} ->
  #       Logger.warn("payflow error: #{inspect(error, pretty: true)}")

  #       send_resp(
  #         conn,
  #         200,
  #         %{stat: @err_payflow_networkd, res: "my server network error"} |> Jason.encode!()
  #       )
  #   end
  # end

  # post "/buygoods" do
  #   # Logger.debug("conn is #{inspect(conn, pretty: true)}")

  #   length =
  #     conn.req_headers |> Map.new() |> Map.get("content-length", "0") |> String.to_integer()

  #   case Plug.Conn.read_body(conn, length: length) do
  #     {:ok, body, conn} ->
  #       Logger.debug("buygoods request body: #{inspect(body, pretty: true)}")

  #       try do
  #         {stat, res} = BuyGoods.analyze(body)

  #         Logger.debug("buygoods stat: #{stat}, res: #{inspect(res, pretty: true)}")
  #         send_resp(conn, 200, %{stat: stat, res: res} |> Jason.encode!())
  #       rescue
  #         err ->
  #           Logger.warn(fn ->
  #             "buygoods err: #{inspect(err, pretty: true)}, body: #{inspect(body, pretty: true)}, stacktrace is #{
  #               inspect(:erlang.get_stacktrace(), pretty: true)
  #             }"
  #           end)

  #           send_resp(
  #             conn,
  #             200,
  #             %{stat: @err_payflow_internal, res: "my server internal error"} |> Jason.encode!()
  #           )
  #       end

  #     {:error, error} ->
  #       Logger.warn("buygoods error: #{inspect(error, pretty: true)}")

  #       send_resp(
  #         conn,
  #         200,
  #         %{stat: @err_payflow_networkd, res: "my server network error"} |> Jason.encode!()
  #       )
  #   end
  # end

  # post "/open" do
  #   conn = fetch_query_params(conn)

  #   case conn.params do
  #     %{"time" => time} ->
  #       ts = time |> String.to_integer()
  #       {{year, month, day}, {hour, _, _}} = ts |> Utils.ts_to_tuple()
  #       Application.put_env(:my_server, :boot_up_time, {{year, month, day}, {hour, 00, 00}})
  #       Character.persistence("env", "bootup", %{time: ts})
  #       send_resp(conn, 200, "success")

  #     _ ->
  #       send_resp(conn, 200, "invalid param")
  #   end
  # end

  # post "/gift" do
  #   length =
  #     conn.req_headers |> Map.new() |> Map.get("content-length", "0") |> String.to_integer()

  #   body =
  #     case Plug.Conn.read_body(conn, length: length) do
  #       {:ok, body, _conn} ->
  #         Jason.decode!(body)

  #       _ ->
  #         %{}
  #     end

  #   case body do
  #     %{"platform" => platform, "nickname" => nickname, "role_id" => role_id} ->
  #       Account.gift_mail(platform, nickname, role_id)
  #       send_resp(conn, 200, "success")

  #     _ ->
  #       send_resp(conn, 200, "invalid param")
  #   end
  # end

  match _ do
    send_resp(conn, 404, "Oops!")
  end

end
