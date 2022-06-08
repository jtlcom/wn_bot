defmodule Lala do
  use BaseHtml, [html: :lala]
  # alias Lala.Event

  def args() do
    [
      onlines: SimpleStatistics.get_onlines(),
      total_num: SimpleStatistics.get_total_num(),
      events: SimpleStatistics.get_infos()
    ]
  end
  
end

defmodule Lala.Event do
  @behaviour Access

  defstruct eid: 0,
    name: "",
    count: 0,
    max_consume: 0,
    min_consume: 0,
    avg_consume: 0,
    fifty: 0,
    seventy_five: 0,
    ninty: 0,
    ninty_five: 0

  def fetch(struc, key) do
    {:ok, Map.get(struc, key)}
  end

  def get_and_update(struc, k, func) do
    {struc[k], Map.put(struc, k, func.(struc[k]))}
  end

  def pop(struc, k) do
    Map.put(struc, k, 0)
  end

end