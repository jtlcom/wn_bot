defmodule BaseHtml do
  defmacro __using__([html: html]) do
    quote do
      # import EExHTML
      require EEx
      require Logger
      @html unquote("./lib/http/web/html/" <> to_string(html))
      @web_suffix [".html", ".jsp", ".eex"]

      def html() do
        exist_suffix = Enum.find(@web_suffix, fn suffix ->
          # IO.inspect @html <> suffix
          File.exists?(@html <> suffix)
        end)
        # IO.inspect exist_suffix
        Logger.info "exist file : #{exist_suffix}" 
        case exist_suffix && File.exists?(@html <> exist_suffix) do
          true ->
            EEx.eval_file(@html <> exist_suffix, args())
          _ ->
            ""
        end
      end

      def generate_html() do
        html()
      end

      def args() do
        []
      end

      defoverridable Module.definitions_in(__MODULE__)

    end
  end
end