Logjam agent for Elixir / Phoenix
===========

This package provides integration with the [Logjam](https://github.com/skaes/logjam_core) monitoring tool for apps that
use the [Phoenix framework](https://github.com/phoenixframework/phoenix).

It buffers all log output for a request and sends the result to a configured AMQP broker when the request was finished.

# Setup

## Configuration
`LogjamAgent` uses a custom `Elixir.Logger` backend to capture and buffer outgoing log output. In the
`config/config.exs` you have to configure the `LogjamAgent.LoggerBackend` as one of the `backends`.

``` Elixir
config :logger,
  format: "$time $metadata[$level] $message\n",
  handle_otp_reports: true,
  handle_sasl_reports: true,
  backends: [:console,  LogjamAgent.LoggerBackend]

```

Another thing that needs to be configured in the `config/config.exs` is the forwarder which pushes
the buffered data to an amqp broker.

``` Elixir
config :logjam_agent, :forwarder,
  enabled: true,
  env: Mix.env,
  app_name: "profileproxy",
  pool_max_overflow: 10,
  pool_size: 20,
  amqp:[
    host: 'broker-1.monitor.edge.fra1.xing.com'
  ]
```

* `enabled` enables or disables the forwarder
* `app_name` specifies the name of the app that is used in `Logjam`
* `env` the xing environment the application runs in
* `initial_connect_delay` the delay in milliseconds before the forwarder should connect to the broker
* `debug_to_stdout` a boolean value indicating whether the forwarder shall print event data to stdout
* `amqp` specifies the options passed to the amqp library. Notably the `host` and `port`.

### Configuration via environment

You can configure the amqp host via the `LOGJAM_BROKER` environment variable.
Note that the environment has precedence over any setting configured in you project's config.

## Phoenix integration

`Phoenix` also needs some minor changes.

In your `web/router.ex` file use `LogjamAgent.Plug` in the appropriate pipeline

``` Elixir
defmodule RestProxy.Router do
  pipeline :browser do
    plug LogjamAgent.Plug
    # ...
  end
end
```

In your  `web/controllers/*` files replace `use Phoenix.Controller` with `use LogjamAgent.Controller`.
In addition to that use the `defaction` macro instead of `def` in order to define your controller action.

``` Elixir
defmodule RestProxy.ProxyController do
  use LogjamAgent.Controller

  defaction proxy(conn, _params) do
    json(conn, 200, %{hello: "world})
  end
end
```

Add Logjam to the application section into your mix.exs i.e.:

```
def application do
  [applications: [..., :logjam_agent], mod: {...}]
end
```

# Note on Patches/Pull Requests ###
* Fork the project on Github.
* Make your feature addition or bug fix.
* Add tests for it, making sure $ mix test is all green.
* Do not rebase other commits than your own
* Do not change the version in the mix file
* Commit
* Send a pull request
