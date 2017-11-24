defmodule LogjamAgent.Mixfile do
  use Mix.Project

  def project do
    [ app: :logjam_agent,
      version: "0.6.3",
      elixir: "~> 1.4",
      elixirc_paths: ["lib"],
      deps: deps()]
  end

  def application do
    [
      mod: { LogjamAgent, [] },
      applications: [
        :ezmq,
        :gen_listener_tcp,
        :lager,
        :logger,
        :plug,
        :poison,
        :poolboy,
        :sasl,
        :uuid,
      ]
    ]
  end

  defp deps do
    [
      {:cowboy,       "~> 1.0.0", optional: true},
      {:phoenix,      "~> 1.3",   optional: true},
      {:plug,         "~> 1.3"    },
      {:uuid,         "~> 1.1"    },
      {:poison,       "~> 3.1"    },
      {:poolboy,      "~> 1.5"    },
      {:lager_logger, "~> 1.0"    },
      {:ezmq,         "~> 0.2.1", git: "https://github.com/zeromq/ezmq.git"},
      {:exbeetle,                 git: "https://source.xing.com/hex/exbeetle", tag: "v0.10.0"},
      {:lager,        "~> 3.5",   override: true},
      {:apex,         "~> 1.0",   only: [:dev, :test]},
      {:credo,        "~> 0.8",   only: [:dev, :test]},
      {:dialyxir,     "~> 0.5",   only: [:dev, :test]},
    ]
  end
end
