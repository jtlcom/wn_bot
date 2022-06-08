defmodule Mnesia.Base do
  defmacro __using__([table: table, attributes: attributes, teble_index: teble_index]) do
    quote do
      alias :mnesia, as: Mnesia
      @table unquote(table)
      @attributes unquote(attributes)
      @teble_index unquote(teble_index)

      def init_store do
        Mnesia.create_table(@table,
          [ram_copies: [Node.self()], attributes: @attributes])# |> #IO.inspect
        Mnesia.add_table_index(@table, @teble_index)
        # :mnesia.info
      end
    
      def copy_store do
        Mnesia.add_table_copy(@table, Node.self(), :ram_copies)
      end
    
      def save_data(key, data) do
        # Mnesia.dirty_write({@table, key, data})
        {:atomic, :ok} = Mnesia.transaction(fn ->
          Mnesia.write({@table, key, data})
        end)
      end
    
      def get_data(key) do
        # Mnesia.dirty_read({@table, key}) 
        {:atomic, data} = Mnesia.transaction(fn -> 
          Mnesia.read({@table, key}) 
        end)
        case Enum.at(data, 0) do
          nil ->
            nil
          {@table, ^key, data} ->
            data
        end
      end 
    
      def del_data(key) do
        # Mnesia.dirty_delete({@table, key})
        Mnesia.transaction(fn -> 
          Mnesia.delete({@table, key}) 
        end)
      end
    
      def del_table() do
        Mnesia.delete_table(@table)
      end

      defoverridable Module.definitions_in(__MODULE__)

    end
  end
end