defmodule LogjamAgent.Mixfile do
  use Mix.Project

  def project do
    [ app: :logjam_agent,
      version: "0.5.10",
      elixir: "~> 1.3",
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
        :ezmq,
        :gen_listener_tcp,
        :sasl,
        :lager
      ]
    ]
  end

  defp deps do
    [
      {:cowboy,       "~> 1.0.0", optional: true},
      {:phoenix,      "~> 1.2", optional: true},
      {:plug,         "~> 1.1"},
      {:uuid,         "~> 1.1"},
      {:poison,       "~> 2.2"},
      {:poolboy,      "~> 1.5"},
      {:ezmq,         git: "https://github.com/zeromq/ezmq.git", tag: "0.2.0"},
      {:exbeetle,     git: "https://source.xing.com/hex/exbeetle", tag: "v0.3.0"},
      {:lager,        "~> 3.2", override: true},
      {:lager_logger, "~> 1.0"},
      {:apex,         "~> 0.5.2", only: [:dev, :test]},
      {:credo,        "~> 0.4", only: [:dev, :test]},
      {:dialyze,      "~> 0.2.0", only: [:dev, :test]}
    ]
  end
end
