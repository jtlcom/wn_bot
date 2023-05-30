defmodule Upload do
  require Logger

  def log(msg) do
    aid = Process.get(:svr_aid, 0)

    aid > 0 &&
      Logger.info(
        "aid #{}, log msg: #{inspect(msg)}" ||
          Logger.info("log msg: #{inspect(msg)}")
      )
  end
end
