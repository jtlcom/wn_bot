defmodule SimpleMsgPack.Packer do
  def pack(nil), do: [0xC0]
  def pack(false), do: [0xC2]
  def pack(true), do: [0xC3]

  def pack(term) when is_atom(term) do
    Atom.to_string(term)
    |> pack
  end

  def pack(term) when is_bitstring(term) do
    size = byte_size(term)
    head = cond do
      size < 32 -> 0b10100000 + size
      size < 256 -> [0xD9, size]
      size < 0x10000 -> <<0xDA, size::16>>
      size < 0x100000000 -> <<0xDB, size::32>>

      true -> throw({:too_big, term})
    end

    [head | term]
  end

  def pack(int) when is_integer(int) do
    if int < 0 do
      cond do
        int >= -32 -> [0x100 + int]
        int >= -128 -> [0xD0, 0x100 + int]
        int >= -0x8000 -> <<0xD1, int::16>>
        int >= -0x80000000 -> <<0xD2, int::32>>
        int >= -0x8000000000000000 -> <<0xD3, int::64>>

        true -> throw({:too_big, int})
      end
    else
      cond do
        int < 128 -> [int]
        int < 256 -> [0xCC, int]
        int < 0x10000 -> <<0xCD, int::16>>
        int < 0x100000000 -> <<0xCE, int::32>>
        int < 0x10000000000000000 -> <<0xCF, int::64>>

        true -> throw({:too_big, int})
      end
    end
  end

  def pack(num) when is_float(num) do
    <<0xCB, num::64-float>>
  end

  def pack(binary) when is_binary(binary) do
    size = byte_size(binary)
    head = cond do
      size < 256 -> [0xC4, size]
      size < 0x10000 -> <<0xC5, size::16>>
      size < 0x100000000 -> <<0xC6, size::32>>

      true -> throw({:too_big, binary})
    end

    [head | binary]
  end

  def pack(list) when is_list(list) do
    length = length(list)
    head = cond do
      length < 16 -> 0b10010000 + length
      length < 0x10000 -> <<0xDC, length::16>>
      length < 0x100000000 -> <<0xDD, length::32>>

      true -> throw({:too_big, list})
    end

    [head] ++ for item <- list do
      pack(item)
    end
  end

  def pack(map) when is_map(map) do
    length = map_size(map)
    head = cond do
      length < 16 -> 0b10000000 + length
      length < 0x10000 -> <<0xDE, length::16>>
      length < 0x100000000 -> <<0xDF, length::32>>

      true -> throw({:too_big, map})
    end

    [head] ++ for {key, value} <- map do
      [pack(key) | pack(value)]
    end
  end

end
