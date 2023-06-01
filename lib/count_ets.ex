defmodule Count.Ets do
  use Ets.RepoAPI,
    name: :count,
    opts: [:named_table, :public, {:read_concurrency, true}]

  def start() do
    init(false)
  end
end
