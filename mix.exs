defmodule LogjamAgent.Mixfile do
  use Mix.Project

  def project do
    [ app: :logjam_agent,
      version: "0.0.1",
      elixir: "~> 1.2",
      elixirc_paths: ["lib"],
      deps: deps]
  end

  def application do
    [
      mod: { LogjamAgent, [] },
      applications: [
        :logger,
        :uuid,
        :poolboy,
        :amqp
      ]
    ]
  end

  defp deps do
    [
      {:cowboy,    "~> 1.0.0", optional: true},
      {:plug,      "~> 1.1.2"},
      {:uuid,      "~> 1.1.0"},
      {:poison,    "~> 1.5.0"},
      {:amqp,      "~> 0.1.4"},
      {:poolboy,   "~> 1.5.0"},
      {:apex,      "~> 0.3.1", only: [:dev, :test]},
      {:credo,      "~> 0.4", only: [:dev, :test]},
    ]
  end
end
