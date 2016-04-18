use Mix.Config

config :logger,
  level: :info

config :logjam_agent, :forwarder,
       env: :test,
       initial_connect_delay: 1,
       enabled: true,
       app_name: :logjam_agent,
       amqp: [host: "localhost"]

