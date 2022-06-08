defmodule SysTool do

  require Logger

  ## 进程的reduction越高，CPU消耗越大
  def process_info(pid) do
    :recon.info pid
  end

  def process_num() do
    length(:erlang.processes())
  end

  ## 通过这个定位最耗CPU的进程
  def max_cpu_processes() do
    :recon.proc_window(:reductions, 10, 500)
  end

  ## 检测端口占用
  def port_num() do
    :recon.port_types()
  end

  ## 内存使用情况，单位转换成了M
  def memory() do
    :erlang.memory()
    |> Enum.map(fn {name, value} -> {name, value / (1024 * 1024)} end)
  end

  ## 查找最耗内存的10个进程
  def max_memory_processes() do
    :recon.proc_count(:memory, 10)
  end

  ## vm调度器利用率，检测CPU利用率
  def scheduler() do
     :recon.scheduler_usage(1000)
  end

  def port_info(port) do
    :recon.port_info port
  end

  ## 查看发送最多网络消息进程
  def check_send_oct() do
    :recon.inet_window(:send_oct, 3, 5000)
  end

  def inet_count() do
    :recon.inet_count(:oct, 3)
  end

  ## 野进程，指没有被链接或者监控的进程
  def wild_process() do
    :erlang.processes()
    |> Enum.filter(fn(pid) -> case :erlang.process_info(pid, [:links, :monitors]) do
                                [{_, _}, {_, _}] ->
                                  false
                                _ ->
                                  true
                              end
    end)
  end

  ## 检测binary是否泄漏
  def bin_leak() do
    :recon.bin_leak 5
  end

  def bin_memory() do
    :recon.proc_count(:binary_memory, 3)
  end

  ## 检测内存碎片
  def memory_usage() do
    :recon_alloc.memory(:usage)
  end

  def memory_alloc() do
    :recon_alloc.memory(:allocated)
  end

  ### profiling, eprof, fprof, eflame
  def fprof(mod, fun, args) do
    :fprof.start()
    :fprof.apply(mod, fun, args)
    :fprof.profile()
    :fprof.analyse()
    :fprof.stop()
  end

  def cur_stack(pid) do
    :recon.info(pid, :current_stacktrace)
  end

  def monitor_gc() do
    :erlang.system_monitor()
    :erlang.system_monitor(self(), [{:long_gc, 500}])
#    flush()
  end

end
