defmodule LogjamAgent.Mixfile do
  use Mix.Project

  def project do
    [ app: :logjam_agent,
      version: "0.0.1",
      elixir: "~> 1.0.0",
      elixirc_paths: ["lib"],
      deps: deps(Mix.env) ]
  end

  def application do
    [
      mod: { LogjamAgent, [] },
      applications: [
        :logger,
        :exrabbit,
        :uuid,
        :poolboy
      ]
    ]
  end

  defp deps(:prod) do
    [
      { :cowboy,      "~> 1.0.0", optional: true},
      { :plug,        "~> 0.7.0"},
      { :httpotion,   "~> 0.2.0" },
      { :uuid,        "~> 0.1.5" },
      { :jazz,        "~> 0.2.1", override: true},
      { :exrabbit,    github: "inbetgames/exrabbit", branch: "refactoring"},
      { :poolboy,     github: "devinus/poolboy", tag: "1.3.0" },
    ]
  end

  defp deps(_) do
    [
      { :apex, "~> 0.3.1" },
    ] ++ deps(:prod)
  end
end
