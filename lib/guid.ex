defmodule Guid do
  import Bitwise
  require Logger
  @server_id 1

  def name(name) when is_atom(name) do
    name
  end

  def name(guid) do
    guid
  end

  def new(:chat, aid) do
    @server_id <<< 40 ||| aid
  end

  def new(:wetest, aid) do
    @server_id <<< 41 ||| aid
  end

  def register(process, name) do
    :global.re_register_name(name, process)
  end

  def whereis(name) do
    :global.whereis_name(name)
  end

end