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
  endpoints:[{:tcp, "broker-1.monitor.preview.fra1.xing.com", 9604}]
```

* `enabled` enables or disables the forwarder
* `app_name` specifies the name of the app that is used in `Logjam`
* `env` the xing environment the application runs in
* `initial_connect_delay` the delay in milliseconds before the forwarder should connect to the broker
* `endpoints` specifies the endpoints for the ZMQP forwarders

### Configuration via environment

You can configure the `logjam_agent` endpoints via the `LOGJAM_BROKER` environment variable.
Note that the environment has precedence over any setting configured in you project's config.

## App integration

Add `logjam_agent` to the application section into your `mix.exs` i.e.:

```elixir
def application do
  [applications: [..., :logjam_agent], mod: {...}]
end
```

### Phoenix controller integration

`Phoenix` also needs some minor changes.

In your `lib/yourapp/endpoint.ex` add `LogjamAgent.Plug.Finalize` before `Logger.Plug`:
``` elixir
  plug Plug.RequestId
  plug LogjamAgent.Plug.Finalize
  plug Plug.Logger
```

In your `web/router.ex` file use `LogjamAgent.Plug.Register` in the appropriate pipeline

``` elixir
defmodule RestProxy.Router do
  pipeline :browser do
    plug LogjamAgent.Plug.Register
    # ...
  end
end
```

In your `web/controllers/*` insert `use LogjamAgent.Action` into your modules.
This will instrument all the exported functions in your controller, so that they will
publish data to logjam.

```elixir
defmodule MyController do
  use LogjamAgent.Action, except: [not_instrumented: 2]

  def index(conn, params) do
    # will be instrumented
  end

  def not_instrumented(conn, params) do
    # wont be instrumented
  end

  def update(conn, params) do
    # will be instrumented
  end
end
```

Note that you can exclude actions from being instrumented by specifying the `:except` option.
All actions that match the name and arity as defined in the `:except` keyword list will
be excluded from instrumentation.

Beside this local list of actions to be excluded you can also configure a global
list of actions to be excluded in all modules. This is done via the `:instrumentation`
configuration.

```elixir
config :logjam_agent, :instrumentation,
       except: [show: 1]
```

### Ecto integration

To track how much time is spent on database actions, you only need to add another logger
for Ecto:

```elixir
# config/config.exs

config :your_app, YourApp.Repo,
  loggers: [
    {Ecto.LogEntry, :log, []},        # default
    {LogjamAgent.TimerEcto, :log, []} # extract timing information
  ]
```

The former logger is the default entry if you do not specify `loggers` at all. It writes a
text version with `:debug` level to your logger backends. If your log level is higher than
that, this logger will be essentially a no-op. The latter one extracts the execution times
and makes them visible in LogJam.

# Note on Patches/Pull Requests ###
* Fork the project on Github.
* Make your feature addition or bug fix.
* Add tests for it, making sure $ mix test is all green.
* Do not rebase other commits than your own
* Do not change the version in the mix file
* Commit
* Send a pull request
