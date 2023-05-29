defmodule Http.Ets do
  use Ets.RepoAPI,
    name: :http,
    opts: [:named_table, :public, {:read_concurrency, true}]

  def start() do
    init(false)
  end
end
