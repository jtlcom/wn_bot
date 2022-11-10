defmodule PressureTest.MixProject do
  use Mix.Project

  def project do
    [
      app: :pressure_test,
      version: "0.1.0",
      elixir: "~> 1.13",
      start_permanent: Mix.env() == :dev,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      applications: applications(Mix.env()),
      mod: {Main, []},
      included_applications: [:logger_file_backend]
    ]
  end

  # def applications(:dev) do
  #   applications(:all) ++ [:changed_reloader]
  # end

  def applications(_) do
    [
      :poolboy,
      :quantum,
      :graphmath,
      :poison,
      :httpoison,
      :timex,
      :tzdata,
      :jason,
      :plug_cowboy,
      :eex_html
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"},
      {:quantum, "~> 2.0"},
      {:timex, "~> 3.0"},
      {:logger_file_backend, "~> 0.0.12"},
      {:poison, "~> 3.0"},
      {:poolboy, ">= 0.0.0"},
      {:httpoison, "~> 0.13"},
      {:graphmath, "~> 1.0"},
      {:changed_reloader, "~> 0.1.4"},
      {:recon, "~> 2.3.6"},
      {:distillery, "~> 2.0"},
      {:jason, "~> 1.1"},
      {:crontab, "~> 1.1"},
      {:logger_file_backend, "~> 0.0.10"},
      {:tzdata, "~> 0.5.19"},
      {:plug_cowboy, "~> 2.0"},
      {:eex_html, git: "https://github.com/CrowdHailer/eex_html"}
    ]
  end
end

Enum.each(Path.wildcard("tasks/*.exs"), &Code.require_file/1)
