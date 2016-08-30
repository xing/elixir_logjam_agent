use Mix.Config

config :logger,
  backends: [LogjamAgent.LoggerBackend]

config :logjam_agent, :forwarder,
       env: :test,
       initial_connect_delay: 1,
       enabled: true,
       app_name: :logjam_agent

# Stub shim for testing
config :logjam_agent, :forwarder_module, LogjamAgent.Forwarders.Stub
