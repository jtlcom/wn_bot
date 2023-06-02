defmodule HandlerSupervisorAPI do
  @moduledoc ~S"""
  独立进程执行API模块

  * 使用方法:
    * use HandlerSupervisorAPI, worker: worker, strategy: strategy
      * worker：执行模块名
      * strategy: 进程策略, 默认为:one_for_one
    * supervisor(worker, [])

  实例
  ```elixir
  defmodule TestServer.Supervisor do
    use HandlerSupervisorAPI, worker: TestServer
  end

  defmodule TestServer do
    use HandlerWorkerAPI, name: :test_worker
  end

  test = fn -> "hello" end
  TestServer.call({:apply, test, []})

  TestServer.call({:apply, Debug, :onlines, []})

  TestServer.cast({:apply, Debug, :onlines, []})
  ```
  """
  defmacro __using__(args) do
    worker = Keyword.get(args, :worker)
    strategy = Keyword.get(args, :strategy, :one_for_one)

    quote do
      @worker unquote(worker)
      require Logger
      use Supervisor

      def start_link do
        Supervisor.start_link(__MODULE__, :ok)
      end

      @impl true
      def init(_) do
        children = [
          {@worker, @worker}
        ]

        Supervisor.init(children, strategy: unquote(strategy))
      end
    end
  end
end

defmodule HandlerAPI do
  @moduledoc ~S"""
  独立进程执行API模块

  * 使用方法:
    * use HandlerAPI, worker: worker, restart: restart, strategy: strategy, is_global: boolean
      * worker：执行模块名
      * restart：重启策略, 默认为:transient
      * strategy: 进程策略, 默认为:one_for_one
      * is_global: 进程是否注册全局名称
    * supervisor(worker, [])

  异步执行
  ```elixir
  def cast({function, args}) :: :ok

  def cast({module, function, args}) :: :ok
  ```

  同步执行
  ```elixir
  def call({function, args}, default :: any, timeout :: integer) :: any

  def call({module, function, args}, default :: any, timeout :: integer) :: any
  ```

  实例
  ```elixir
  defmodule TestHandler do
    use HandlerAPI, worker: TestWorker
  end

  test = fn -> "hello" end
  TestWorker.call({:apply, test, []})

  TestWorker.call({:apply, Debug, :onlines, []})

  TestWorker.cast({:apply, Debug, :onlines, []})
  ```
  """
  defmacro __using__(args) do
    worker = Keyword.get(args, :worker)
    restart = Keyword.get(args, :restart, :transient)
    strategy = Keyword.get(args, :strategy, :one_for_one)
    is_global = Keyword.get(args, :is_global, false)

    quote do
      @worker unquote(worker)
      require Logger
      use Supervisor

      def start_link do
        Supervisor.start_link(__MODULE__, :ok)
      end

      def init(_) do
        children = [
          {@worker, @worker}
        ]

        Supervisor.init(children, strategy: unquote(strategy))
      end

      defmodule @worker do
        use HandlerWorkerAPI, name: @worker, restart: unquote(restart)

        def start_link(name) do
          if unquote(is_global) do
            GenServer.start_link(@worker, :ok, name: {:global, name})
          else
            GenServer.start_link(@worker, :ok, name: name)
          end
        end

        def init(_) do
          {:ok, %{}}
        end
      end
    end
  end
end

defmodule HandlerWorkerAPI do
  @moduledoc ~S"""
  独立进程函数API模块

  * 使用方法:
    * use HandlerWorkerAPI, name: name, restart: restart, is_global: boolean
      * name: 进程名
      * restart：重启策略, 默认为:transient
      * is_global: 进程是否注册全局名称

  异步执行
  ```elixir
  def cast({function, args}) :: :ok

  def cast({module, function, args}) :: :ok
  ```

  同步执行
  ```elixir
  def call({function, args}, default :: any, timeout :: integer) :: any

  def call({module, function, args}, default :: any, timeout :: integer) :: any
  ```
  """
  defmacro __using__(args) do
    name = Keyword.get(args, :name)
    is_global = Keyword.get(args, :is_global, false)
    restart = Keyword.get(args, :restart, :transient)
    call_timeout = Keyword.get(args, :call_timeout, 3000)

    quote do
      use GenServer, restart: unquote(restart)
      require Logger
      @default_reply :default_reply
      @worker __MODULE__
      @name unquote(name)
      @is_global unquote(is_global)
      @call_timeout unquote(call_timeout)

      @doc false
      defmacro ensure_module(mod) do
        if Mix.env() == :dev do
          quote do: Code.ensure_loaded(unquote(mod))
        end
      end

      @doc false
      if @is_global do
        def start_link(args) do
          GenServer.start_link(__MODULE__, args, name: {:global, @name})
        end

        def get_pid() do
          :global.whereis_name(@name)
        end
      else
        def start_link(args) do
          GenServer.start_link(__MODULE__, args, name: @name)
        end

        def get_pid() do
          Process.whereis(@name)
        end
      end

      @doc """
      初始化
      """
      def init(_) do
        Process.flag(:trap_exit, true)
        {:ok, %{}}
      end

      @doc """
      异步执行
      """
      @spec cast(msg :: tuple) :: :ok
      def cast(msg) do
        pid = get_pid()
        is_not_self? = self() != pid

        if is_pid(pid) and is_not_self? do
          GenServer.cast(pid, msg)
        else
          # 以防万一，进程不存在时直接执行操作
          is_not_self? &&
            Logger.warn(
              "#{@worker} cast failed, not found process, direct exec, msg:#{inspect(msg)}"
            )

          case msg do
            {:apply, func, args} when is_function(func) ->
              # 匿名函数
              apply(func, List.wrap(args))

            {:apply, func, args} when is_atom(func) ->
              apply(__MODULE__, func, List.wrap(args))

            {:apply, mod, func, args} when is_atom(func) ->
              ensure_module(mod)
              args = List.wrap(args)

              if function_exported?(mod, func, length(args)) do
                apply(mod, func, args)
              else
                Logger.warn("#{@worker} cast failed, func not exist, msg:#{inspect(msg)}")
              end

            _ ->
              Logger.warn("#{@worker} cast failed, msg format is correct, msg:#{inspect(msg)}")
          end
        end
      rescue
        error ->
          Logger.warn(
            "#{@worker} cast failed, msg:#{inspect(msg)}, error: #{inspect(error)}, stacktrace:#{inspect(__STACKTRACE__)}"
          )
      end

      @doc """
      同步执行
      """
      @spec call(msg :: tuple, default :: any, timeout :: integer) :: any
      def call(msg, default \\ nil, timeout \\ @call_timeout) do
        pid = get_pid()
        is_not_self? = self() != pid

        if is_pid(pid) and is_not_self? do
          try do
            GenServer.call(pid, {msg, default}, timeout)
          catch
            :exit, reason ->
              Logger.warn(
                "#{@worker} call failed, reason:#{inspect(reason)}, direct exec, msg:#{inspect(msg)}"
              )

              default
          end
        else
          # 以防万一，进程不存在时直接执行操作
          is_not_self? &&
            Logger.warn(
              "#{@worker} call failed, not found process, direct exec, msg:#{inspect(msg)}"
            )

          case msg do
            {:apply, func, args} when is_function(func) ->
              # 匿名函数
              apply(func, List.wrap(args))

            {:apply, mod, func, args} when is_atom(func) ->
              ensure_module(mod)
              args = List.wrap(args)

              if function_exported?(mod, func, length(args)) do
                apply(mod, func, args)
              else
                Logger.warn("#{@worker} call failed, func not exist, msg:#{inspect(msg)}")
                default
              end

            _ ->
              Logger.warn("#{@worker} call failed, msg format is correct, msg:#{inspect(msg)}")
              default
          end
        end
      rescue
        error ->
          Logger.warn(
            "#{@worker} call failed, msg:#{inspect(msg)}, error: #{inspect(error)}, stacktrace:#{inspect(__STACKTRACE__)}"
          )

          default
      end

      def get_state() do
        call({:apply_with_state, fn state -> state end, []})
      end

      def handle_call({{:apply, func, args} = msg, default}, _from, state) when is_atom(func) do
        {:reply, apply(__MODULE__, func, args), state}
      rescue
        error ->
          Logger.warn(
            "#{@worker} handle_call failed, msg:#{inspect(msg)}, error: #{inspect(error)}, stacktrace:#{inspect(__STACKTRACE__)}"
          )

          {:reply, default, state}
      end

      def handle_call({{:apply, func, args} = msg, default}, _from, state)
          when is_function(func) do
        {:reply, apply(func, args), state}
      rescue
        error ->
          Logger.warn(
            "#{@worker} handle_call failed, msg:#{inspect(msg)}, error: #{inspect(error)}, stacktrace:#{inspect(__STACKTRACE__)}"
          )

          {:reply, default, state}
      end

      def handle_call({{:apply_with_state, func, args} = msg, default}, _from, state)
          when is_atom(func) do
        case apply(__MODULE__, func, args ++ [state]) do
          {:ok, new_state} -> {:reply, :ok, new_state}
          {:ok, reply, new_state} -> {:reply, reply, new_state}
          reply -> {:reply, reply, state}
        end
      rescue
        error ->
          Logger.warn(
            "#{@worker} handle_call failed, msg:#{inspect(msg)}, error: #{inspect(error)}, stacktrace:#{inspect(__STACKTRACE__)}"
          )

          {:reply, default, state}
      end

      def handle_call({{:apply_with_state, func, args} = msg, default}, _from, state)
          when is_function(func) do
        case apply(func, args ++ [state]) do
          {:ok, new_state} -> {:reply, :ok, new_state}
          {:ok, reply, new_state} -> {:reply, reply, new_state}
          reply -> {:reply, reply, state}
        end
      rescue
        error ->
          Logger.warn(
            "#{@worker} handle_call failed, msg:#{inspect(msg)}, error: #{inspect(error)}, stacktrace:#{inspect(__STACKTRACE__)}"
          )

          {:reply, default, state}
      end

      def handle_call({{:apply, mod, func, args} = msg, default}, _from, state) do
        ensure_module(mod)
        {:reply, apply(mod, func, args), state}
      rescue
        error ->
          Logger.warn(
            "#{@worker} handle_call failed, msg:#{inspect(msg)}, error: #{inspect(error)}, stacktrace:#{inspect(__STACKTRACE__)}"
          )

          {:reply, default, state}
      end

      def handle_call({{:apply_with_state, mod, func, args} = msg, default}, _from, state) do
        ensure_module(mod)

        case apply(mod, func, args ++ [state]) do
          {:ok, new_state} -> {:reply, :ok, new_state}
          {:ok, reply, new_state} -> {:reply, reply, new_state}
          reply -> {:reply, reply, state}
        end
      rescue
        error ->
          Logger.warn(
            "#{@worker} handle_call failed, msg:#{inspect(msg)}, error: #{inspect(error)}, stacktrace:#{inspect(__STACKTRACE__)}"
          )

          {:reply, default, state}
      end

      def handle_cast({:apply, func, args} = msg, state) when is_atom(func) do
        apply(__MODULE__, func, args)
        {:noreply, state}
      rescue
        error ->
          Logger.warn(
            "#{@worker} handle_cast failed, msg:#{inspect(msg)}, error: #{inspect(error)}, stacktrace:#{inspect(__STACKTRACE__)}"
          )

          {:noreply, state}
      end

      def handle_cast({:apply, func, args} = msg, state) when is_function(func) do
        apply(func, args)
        {:noreply, state}
      rescue
        error ->
          Logger.warn(
            "#{@worker} handle_cast failed, msg:#{inspect(msg)}, error: #{inspect(error)}, stacktrace:#{inspect(__STACKTRACE__)}"
          )

          {:noreply, state}
      end

      def handle_cast({:apply_with_state, func, args} = msg, state) when is_atom(func) do
        case apply(__MODULE__, func, args ++ [state]) do
          {:ok, new_state} -> {:noreply, new_state}
          _ -> {:noreply, state}
        end
      rescue
        error ->
          Logger.warn(
            "#{@worker} handle_cast failed, msg:#{inspect(msg)}, error: #{inspect(error)}, stacktrace:#{inspect(__STACKTRACE__)}"
          )

          {:noreply, state}
      end

      def handle_cast({:apply_with_state, func, args} = msg, state) when is_function(func) do
        case apply(func, args ++ [state]) do
          {:ok, new_state} -> {:noreply, new_state}
          _ -> {:noreply, state}
        end
      rescue
        error ->
          Logger.warn(
            "#{@worker} handle_cast failed, msg:#{inspect(msg)}, error: #{inspect(error)}, stacktrace:#{inspect(__STACKTRACE__)}"
          )

          {:noreply, state}
      end

      def handle_cast({:apply, mod, func, args} = msg, state) do
        ensure_module(mod)
        apply(mod, func, args)
        {:noreply, state}
      rescue
        error ->
          Logger.warn(
            "#{@worker} handle_cast failed, msg:#{inspect(msg)}, error: #{inspect(error)}, stacktrace:#{inspect(__STACKTRACE__)}"
          )

          {:noreply, state}
      end

      def handle_cast({:apply_with_state, mod, func, args} = msg, state) do
        ensure_module(mod)

        case apply(mod, func, args ++ [state]) do
          {:ok, new_state} -> {:noreply, new_state}
          _ -> {:noreply, state}
        end
      rescue
        error ->
          Logger.warn(
            "#{@worker} handle_cast failed, msg:#{inspect(msg)}, error: #{inspect(error)}, stacktrace:#{inspect(__STACKTRACE__)}"
          )

          {:noreply, state}
      end

      def handle_info({:apply, func, args} = msg, state) when is_atom(func) do
        apply(__MODULE__, func, args)
        {:noreply, state}
      rescue
        error ->
          Logger.warn(
            "#{@worker} handle_info failed, msg:#{inspect(msg)}, error: #{inspect(error)}, stacktrace:#{inspect(__STACKTRACE__)}"
          )

          {:noreply, state}
      end

      def handle_info({:apply, func, args} = msg, state) when is_function(func) do
        apply(func, args)
        {:noreply, state}
      rescue
        error ->
          Logger.warn(
            "#{@worker} handle_info failed, msg:#{inspect(msg)}, error: #{inspect(error)}, stacktrace:#{inspect(__STACKTRACE__)}"
          )

          {:noreply, state}
      end

      def handle_info({:apply, mod, func, args} = msg, state) do
        ensure_module(mod)
        apply(mod, func, args)
        {:noreply, state}
      rescue
        error ->
          Logger.warn(
            "#{@worker} handle_info failed, msg:#{inspect(msg)}, error: #{inspect(error)}, stacktrace:#{inspect(__STACKTRACE__)}"
          )

          {:noreply, state}
      end

      def handle_info({:apply_with_state, func, args} = msg, state) when is_atom(func) do
        case apply(__MODULE__, func, args ++ [state]) do
          {:ok, new_state} -> {:noreply, new_state}
          _ -> {:noreply, state}
        end
      rescue
        error ->
          Logger.warn(
            "#{@worker} handle_cast failed, msg:#{inspect(msg)}, error: #{inspect(error)}, stacktrace:#{inspect(__STACKTRACE__)}"
          )

          {:noreply, state}
      end

      def handle_info({:apply_with_state, func, args} = msg, state) when is_function(func) do
        case apply(func, args ++ [state]) do
          {:ok, new_state} -> {:noreply, new_state}
          _ -> {:noreply, state}
        end
      rescue
        error ->
          Logger.warn(
            "#{@worker} handle_cast failed, msg:#{inspect(msg)}, error: #{inspect(error)}, stacktrace:#{inspect(__STACKTRACE__)}"
          )

          {:noreply, state}
      end

      def handle_info({:apply_with_state, mod, func, args} = msg, state) do
        ensure_module(mod)

        case apply(mod, func, args ++ [state]) do
          {:ok, new_state} -> {:noreply, new_state}
          _ -> {:noreply, state}
        end
      rescue
        error ->
          Logger.warn(
            "#{@worker} handle_cast failed, msg:#{inspect(msg)}, error: #{inspect(error)}, stacktrace:#{inspect(__STACKTRACE__)}"
          )

          {:noreply, state}
      end

      def handle_info({:EXIT, _, reason}, state) do
        Logger.warn("#{@worker} EXIT, reason:#{inspect(reason)}")
        {:stop, reason, state}
      end

      # def handle_info(msg, state) do
      #   Logger.warn("#{@worker} handle_info failed, msg:#{inspect(msg)}")
      #   {:noreply, state}
      # end

      def terminate(reason, _state) do
        Logger.info("#{@worker} terminate, reason:#{inspect(reason)}")
      end

      defoverridable init: 1, terminate: 2
    end
  end
end

defmodule InvokeHandlerAPI do
  @moduledoc ~S"""
  调用独立进程函数API模块

  * 使用方法:
    * use InvokeHandlerAPI, handler_name: handler_name, timeout: timeout
      * handler_name: 被调用进程名
      * timeout: 调用超时时间

  异步执行
  ```elixir
  def cast({function, args}) :: :ok

  def cast({module, function, args}) :: :ok
  ```

  同步执行
  ```elixir
  def call({function, args}, default :: any, timeout :: integer) :: any

  def call({module, function, args}, default :: any, timeout :: integer) :: any
  ```
  """
  defmacro __using__(args) do
    handler_name = Keyword.get(args, :handler_name)
    call_timeout = Keyword.get(args, :call_timeout, 3000)

    quote do
      require Logger
      @handler_name unquote(handler_name)
      @call_timeout unquote(call_timeout)

      @doc false
      def get_pid() do
        :global.whereis_name(@handler_name)
      end

      def call(msg, default \\ nil, timeout \\ @call_timeout)

      def call({_fun, _args} = msg, default, timeout) do
        pid = get_pid()

        if is_pid(pid) do
          try do
            GenServer.call(pid, {msg, default}, timeout)
          catch
            :exit, reason ->
              Logger.warn(
                "#{__MODULE__} call failed, reason:#{inspect(reason)}, msg:#{inspect(msg)}"
              )

              default
          end
        else
          Logger.warn("#{__MODULE__} call failed, not found process, msg:#{inspect(msg)}")
          default
        end
      end

      def call({_mod, _fun, _args} = msg, default, timeout) do
        pid = get_pid()

        if is_pid(pid) do
          try do
            GenServer.call(pid, {msg, default}, timeout)
          catch
            :exit, reason ->
              Logger.warn(
                "#{__MODULE__} call failed, reason:#{inspect(reason)}, msg:#{inspect(msg)}"
              )

              default
          end
        else
          Logger.warn("#{__MODULE__} call failed, not found process, msg:#{inspect(msg)}")
          default
        end
      end

      def call(msg, default, _timeout) do
        Logger.warn("#{__MODULE__} call failed, msg incorrect, msg:#{inspect(msg)}")
        default
      end

      def cast({_fun, _args} = msg) do
        pid = get_pid()

        if is_pid(pid) do
          try do
            GenServer.cast(pid, msg)
          catch
            :exit, reason ->
              Logger.warn(
                "#{__MODULE__} cast failed, reason:#{inspect(reason)}, msg:#{inspect(msg)}"
              )

              :failed
          end
        else
          Logger.warn("#{__MODULE__} cast failed, not found process, msg:#{inspect(msg)}")
          :failed
        end
      end

      def cast({_mod, _fun, _args} = msg) do
        pid = get_pid()

        if is_pid(pid) do
          try do
            GenServer.cast(pid, msg)
          catch
            :exit, reason ->
              Logger.warn(
                "#{__MODULE__} cast failed, reason:#{inspect(reason)}, msg:#{inspect(msg)}"
              )

              :failed
          end
        else
          Logger.warn("#{__MODULE__} cast failed, not found process, msg:#{inspect(msg)}")
          :failed
        end
      end

      def cast(msg) do
        Logger.warn("#{__MODULE__} cast failed, msg incorrect, msg:#{inspect(msg)}")
        :failed
      end
    end
  end
end
