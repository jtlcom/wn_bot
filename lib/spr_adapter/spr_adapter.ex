defmodule SprAdapter do
  # 腾讯压测大师
  use HandlerWorkerAPI, name: __MODULE__
  require Logger

  def base_config(), do: Application.get_env(:whynot_bot, SprAdapter)
  def url(), do: base_config()[:url]
  def internal(), do: base_config()[:report_internal]

  def init(_) do
    case base_config()[:is_use] do
      true -> Process.send_after(self(), :loop, 100)
      _ -> nil
    end

    {:ok, %{}}
  end

  def handle_info(:loop, state) do
    Process.send_after(self(), :loop, internal())
    state = SprAdapter.check(state)
    {:noreply, state}
  end

  def handle_cast({:start, nums}, state) do
    url = "#{url()}/report/start"
    data = %{robotCount: nums}

    case SprAdapter.do_request(url, data) do
      {:ok, %{"id" => sqr_id}} ->
        new_state = state |> Map.merge(%{id: sqr_id, bot_nums: nums, collect_data: []})
        {:noreply, new_state}

      _ ->
        {:noreply, state}
    end
  end

  def handle_cast({:collect, key, start_ms, end_ms}, %{collect_data: coll_data} = state) do
    coll_data = coll_data ++ [[key, start_ms, end_ms]]
    new_state = state |> Map.merge(%{collect_data: coll_data})
    {:noreply, new_state}
  end

  def handle_cast(_, state) do
    {:noreply, state}
  end

  def check(%{id: sqr_id, bot_nums: init_nums, collect_data: coll_data} = state) do
    url = "#{url()}/report/collectdata"
    online_nums = Avatars.number()
    stop_nums = trunc(init_nums - online_nums) |> max(0)

    samplerlist =
      Enum.flat_map(coll_data, fn
        [key, start_ms, end_ms] ->
          [
            %{
              key: key,
              result: 1,
              startTime: start_ms,
              endTime: end_ms
            }
          ]

        _ ->
          []
      end)

    data = %{
      id: sqr_id,
      robotRunCount: online_nums,
      robotStopCount: stop_nums,
      samplerlist: samplerlist
    }

    File.write("spr_adapter.log", "#{inspect(Timex.now())}: #{inspect(data)}\n", [:append])
    SprAdapter.do_request(url, data)

    state |> Map.put(:collect_data, [])
  rescue
    _ -> state
  end

  def check(state), do: state

  def do_request(url, data) do
    header = [{"Content-Type", "application/json"}]

    case HTTPoison.post(url, Jason.encode_to_iodata!(data), header, timeout: 3000) do
      {:ok, %{status_code: 200, body: body}} ->
        data = Jason.decode!(body)
        File.write("spr_adapter.log", "#{inspect(Timex.now())}: #{inspect(data)}\n", [:append])
        {:ok, data}

      error ->
        Logger.warning(
          "#{__MODULE__} do_request failed, url:#{url}, data:#{inspect(data)}, error:#{inspect(error)}"
        )

        :failed
    end
  end
end
