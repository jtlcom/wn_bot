defmodule TradeBank do
  
  def submit_all(lines \\ :all) do
    :trade_all
    |> Realm.broadcast_avatars_handle(lines)
  end

  def submit_some(num, lines \\ :all) do
    {:trade_some, num}
    |> Realm.broadcast_avatars_handle(lines)
  end

  def start_query(lines \\ :all) do
    :set_trade_query
    |> Realm.broadcast_avatars_handle(lines)
  end

  def stop_query(lines \\ :all) do
    :stop_query
    |> Realm.broadcast_avatars_handle(lines)
  end
  
end