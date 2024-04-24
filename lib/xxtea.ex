defmodule Xxtea do
  import Bitwise
  @delta 0x9E3779B9

  defp binary_to_int_list(li, include_length) when is_list(li) do
    binary_to_int_list(:erlang.list_to_binary(li), include_length)
  end

  defp binary_to_int_list(bin, include_length) do
    binary_length = :erlang.size(bin)
    binary_index = binary_length - 1

    case include_length do
      true ->
        make_int_list(bin, [0 | [binary_length]], binary_index, bsr(binary_index, 2))

      false ->
        make_int_list(bin, [0], binary_index, bsr(binary_index, 2))
    end
  end

  defp make_int_list(_, array, -1, _) do
    array
  end

  defp make_int_list(bin, int_array, b_index, i_index) when bsr(b_index, 2) !== i_index do
    make_int_list(bin, [0 | int_array], b_index, bsr(b_index, 2))
  end

  defp make_int_list(bin, [array_head | array_tail], b_index, i_index) do
    new_addend = convert_byte_to_int(bin, b_index)
    curr_int_value = int32(bor(array_head, new_addend))
    make_int_list(bin, [curr_int_value | array_tail], b_index - 1, i_index)
  end

  defp convert_byte_to_int(bin, index) do
    <<_::binary-size(index), byte_value, _::binary>> = bin
    bsl(byte_value, bsl(band(index, 3), 3))
  end

  defp int_list_to_binary(int_array, false) when is_list(int_array) do
    int_list_to_binary(int_array, bsl(length(int_array), 2), [], 0, 0)
  end

  defp int_list_to_binary(int_array, true) when is_list(int_array) do
    data_length = :lists.last(int_array)

    case data_length > bsl(length(int_array), 2) do
      true ->
        :bad_data

      false ->
        int_list_to_binary(int_array, data_length, [], 0, 0)
    end
  end

  defp int_list_to_binary(_, data_length, binary_list, data_length, _) do
    :erlang.list_to_binary(:lists.reverse(binary_list))
  end

  defp int_list_to_binary([_ | int_tail], data_length, binary_list, index, int_array_index)
       when bsr(index, 2) !== int_array_index do
    int_list_to_binary(int_tail, data_length, binary_list, index, bsr(index, 2))
  end

  defp int_list_to_binary(
         [int_head | _] = int_array,
         data_length,
         binary_list,
         index,
         int_array_index
       ) do
    int_list_to_binary(
      int_array,
      data_length,
      [get_byte_from_int(int_head, index) | binary_list],
      index + 1,
      int_array_index
    )
  end

  defp get_byte_from_int(num, index) do
    band(bsr(num, bsl(band(index, 3), 3)), 0xFF)
  end

  def encrypt(data, key) when is_list(data) and is_list(key) do
    int_list_to_binary(
      encrypt_int_list(binary_to_int_list(data, true), binary_to_int_list(key, false)),
      false
    )
  end

  defp encrypt_int_list(value, _key) when is_list(value) and length(value) == 0 do
    value
  end

  defp encrypt_int_list(value, key) when is_list(key) and length(key) < 4 do
    encrypt_int_list(value, formal_key(key))
  end

  defp encrypt_int_list(value, key) when is_list(value) and is_list(key) do
    n = length(value) - 1
    z = :lists.last(value)
    sum = 0
    q = floor(6 + div(52, n + 1))
    encrypt_loop1(value, key, z, sum, q)
  end

  defp encrypt_loop1(value, key, z, sum, q) when q > 0 do
    sum2 = int32(sum + @delta)
    e = band(bsr(sum2, 2), 3)
    encrypt_loop2(value, key, [], z, sum2, e, 0, q - 1)
  end

  defp encrypt_loop1(value, _key, _z, _sum, _q) do
    value
  end

  defp encrypt_loop2([x], key, encrypt_list, z, sum, e, p, q) do
    y = :lists.last(encrypt_list)
    z2 = int32(x + calc_bit_operation_value(y, z, key, p, e, sum))
    encrypt_loop1(:lists.reverse([z2 | encrypt_list]), key, z2, sum, q)
  end

  defp encrypt_loop2([x, y | _] = value, key, encrypt_list, z, sum, e, p, q) do
    z2 = int32(x + calc_bit_operation_value(y, z, key, p, e, sum))
    encrypt_loop2(tl(value), key, [z2 | encrypt_list], z2, sum, e, p + 1, q)
  end

  defp calc_bit_operation_value(y, z, key, p, e, sum) do
    temp = :lists.nth(bxor(band(p, 3), e) + 1, key)
    temp2 = band(bsr(z, 5), 0x07FFFFFF)
    temp3 = bsl(y, 2)
    temp4 = bxor(temp2, temp3)
    temp5 = band(bsr(y, 3), 0x1FFFFFFF)
    temp6 = bsl(z, 4)
    temp7 = bxor(temp5, temp6)
    temp8 = int32(temp4 + temp7)
    temp9 = bxor(sum, y)
    temp10 = bxor(temp, z)
    temp11 = int32(temp9 + temp10)
    bxor(temp8, temp11)
  end

  def decrypt(data, _key) when is_binary(data) and :erlang.size(data) == 0 do
    ""
  end

  def decrypt(data, key) when is_binary(data) do
    int_list_to_binary(
      decrypt_int_list(binary_to_int_list(data, false), binary_to_int_list(key, false)),
      true
    )
  end

  defp decrypt_int_list(data, key) when is_list(key) and length(key) < 4 do
    decrypt_int_list(data, formal_key(key))
  end

  defp decrypt_int_list(data, key) when is_list(data) and is_list(key) do
    n = length(data) - 1
    y = hd(data)
    q = floor(6 + div(52, n + 1))
    sum = int32(q * @delta)
    decrypt_loop1(data, key, sum, y, n)
  end

  defp decrypt_loop1(data, key, sum, y, n) when sum !== 0 do
    e = band(bsr(sum, 2), 3)
    decrypt_loop2(:lists.reverse(data), key, [], y, sum, e, n, n)
  end

  defp decrypt_loop1(data, _key, _sum, _y, _n) do
    data
  end

  defp decrypt_loop2([x], key, decrypt_list, y, sum, e, p, n) do
    z = :lists.last(decrypt_list)
    y2 = int32(x - calc_bit_operation_value(y, z, key, p, e, sum))
    decrypt_loop1([y2 | decrypt_list], key, int32(sum - @delta), y2, n)
  end

  defp decrypt_loop2([x, z | _] = reverse_data, key, decrypt_list, y, sum, e, p, n) do
    y2 = int32(x - calc_bit_operation_value(y, z, key, p, e, sum))
    decrypt_loop2(tl(reverse_data), key, [y2 | decrypt_list], y2, sum, e, p - 1, n)
  end

  defp formal_key(key) do
    key_length = length(key)

    cond do
      key_length > 4 ->
        :lists.sublist(key, 1, 4)

      key_length == 4 ->
        key

      true ->
        key ++ :lists.duplicate(4 - key_length, 0)
    end
  end

  defp int32(num) do
    n1 = band(num, 0xFFFFFFFF)

    case n1 <= 0x7FFFFFFF do
      true ->
        n1

      false ->
        n1 - 0xFFFFFFFF - 1
    end
  end

  if not Version.match?(System.version(), ">= 1.8.0") do
    defp floor(x) do
      t = :erlang.trunc(x)

      case x - t do
        neg when neg < 0 ->
          t - 1

        pos when pos > 0 ->
          t

        _ ->
          t
      end
    end
  end
end
