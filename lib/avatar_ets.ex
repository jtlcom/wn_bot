defmodule Avatar.Ets do
  use Ets.RepoAPI,
    name: :avatar,
    opts: [:named_table, :public, {:read_concurrency, true}]

  def start() do
    init(false)
  end
end
