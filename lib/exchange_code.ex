defmodule ExchangeCode do
    
  alias Poison.Parser
  alias Poison.Encoder

  def decode(packet) do
    [_type | _msg] = Parser.parse!(packet)
  end

  def encode(msg) do
    Encoder.encode(msg, [])
  end

end