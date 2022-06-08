defmodule Auction do
  use GameDef
  GameDef.defconst(path: "auctions/config/discrete_data", getter: :config)
  
  # @num 10
  # @delay 20
  def start_auction(lines \\ :all) do
    # 1..@num
    # |> Enum.each(fn _ ->
      {:start_auction, 20}
      |> Realm.broadcast_avatars_handle(lines)
    #   Process.sleep(@delay * 1000)
    # end) 
  end

  def calc_bid_price(base_price, cur_price) do
    add_val = Float.ceil(base_price * config()[:increment_percent] * 0.01)
    trunc(cur_price + add_val)
  end

end