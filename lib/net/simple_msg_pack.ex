defmodule SimpleMsgPack do

  require Logger

  alias __MODULE__.Packer
  alias __MODULE__.Unpacker

  def pack(term, options \\ []) when is_list(options) do
    iodata? = Keyword.get(options, :iodata, true)

    try do
      Packer.pack(term)
    catch
      :throw, reason ->
        {:error, {:reason, reason}}
    else
      iodata when iodata? ->
      {:ok, iodata}
      iodata ->
      {:ok, IO.iodata_to_binary(iodata)}
    end
  end

  def pack!(term, options \\ []) do
    case pack(term, options) do
      {:ok, result} ->
        result
      {:error, exception} ->
        raise exception
    end
  end

  def unpack_slice(iodata, options \\ []) when is_list(options) do
    try do
      iodata
      |> IO.iodata_to_binary()
      |> Unpacker.unpack(options)
    catch
      :throw, reason ->
        {:error, reason}
    else
      {value, rest} ->
        {:ok, value, rest}
    end
  end

  def unpack_slice!(iodata, options \\ []) do
    case unpack_slice(iodata, options) do
      {:ok, value, rest} ->
        {value, rest}
      {:error, exception} ->
        raise exception
    end
  end

  def unpack(iodata, options \\ []) do
    case unpack_slice(iodata, options) do
      {:ok, value, <<>>} ->
        {:ok, value}
      {:ok, _, bytes} ->
        {:error, {:reason, {:excess_bytes, bytes}}}
      {:error, _} = error ->
        error
    end
  end

  def unpack!(iodata, options \\ []) do
    case unpack(iodata, options) do
      {:ok, value} ->
        value
      {:error, exception} ->
        raise exception
    end
  end
end
