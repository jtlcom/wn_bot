defmodule Realm do
  require Logger

  def control(avatar, request) do
    GenServer.cast(avatar, request)
  end
end
