defmodule WhynotBot.MixProject do
  use Mix.Project

  def project do
    [
      app: :whynot_bot,
      version: "0.1.0",
      elixir: "~> 1.13",
      start_permanent: Mix.env() == :dev,
      deps: deps(),
      releases: [
        whynot_bot: [
          steps: [:assemble, :tar]
        ]
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      applications: applications(Mix.env()),
      mod: {Main, []},
      included_applications: included_applications(:os.type())
    ]
  end

  def applications(:dev) do
    applications(:all) ++ [:changed_reloader]
  end

  def applications(_) do
    [
      :poolboy,
      :timex,
      :jason,
      :httpoison,
      :plug_cowboy,
      :mqtt
    ]
  end

  def included_applications({:win32, _}) do
    [:logger_file_backend, :observer, :wx, :runtime_tools]
  end

  def included_applications(_) do
    [:logger_file_backend]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"},
      {:timex, "~> 3.0"},
      {:logger_file_backend, "~> 0.0.12"},
      {:poolboy, ">= 0.0.0"},
      {:changed_reloader,
       git: "http://wn-server-1:8081/huangbo/changed_reloader", only: :dev, tag: "1.5"},
      {:jason, "~> 1.1"},
      {:httpoison, "~> 1.0"},
      {:plug_cowboy, "~> 2.0"},
      {:mqtt, "~> 0.3.3"},
      {:msgpax, "~> 2.4"}
    ]
  end
end

Enum.each(Path.wildcard("tasks/*.exs"), &Code.require_file/1)
