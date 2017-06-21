# Changelog

## 0.5.15

* fix possible memory/process leak with ZMQForwarder during bursts
  [#23](https://source.xing.com/hex/logjam_agent/pull/23)
* pass request URL to logjam as well and filter out sensitive parameters
  [#24](https://source.xing.com/hex/logjam_agent/pull/24)

## 0.5.14
* Simple instrumentation does not require particular return value of instrumented function
  [#22](https://source.xing.com/hex/logjam_agent/pull/22)

## 0.5.13
* Introduce Simple instrumentation for vanilla Elixir functions [#21](https://source.xing.com/hex/logjam_agent/pull/21)

## 0.5.12

* Update exbeetle to v0.6.0 [#20](https://source.xing.com/hex/logjam_agent/pull/20)


## 0.5.11

* report just `request_id` to logjam, but full `current_caller_id` in HTTP header (#19)

## 0.5.10

* fix breakage and memory leaks introduced in 0.5.9 (#18)
* adds app_name and environment to request_id (#17)
* the API changes mentioned in 0.5.9 still need to be applied

## 0.5.9

**Broken, do not use**

* reports logs for halted controller actions as well. __This patch changes how you need to integrate the Logjam Agent into your app:__
  * in `web/router.ex`, you need to rename `LogjamAgent.Plug` → `LogjamAgent.Plug.Register`
  * in `lib/yourapp/endpoint.ex`, you need to add `plug LogjamAgent.Plug.Finalize` as described in the [README.md](README.md)

## 0.5.8
* Store action name in Metadata to make it available in controllers

## 0.5.7
* Add CI build scripts

## 0.5.6
* Fix memory leak that caused dangling log messages in `LogjamAgent.Buffer` for channel and socket messages.

## 0.5.5
* Defer stringification of nested maps in request_headers to JSON encoder

## 0.5.4
* Make sure that `request_headers` map sent to logjam is always a map from string to string

## 0.5.3

* Do not append `topic` or `event` in the case of `Channel.join`

## 0.5.2
* Append `topic` or `event` to channel and socket instrumentation send to logjam [#8](https://source.xing.com/hex/logjam_agent/pull/8)
* Ensure that `request_id` is set in process metadata for channel and socket instrumentation [#7](https://source.xing.com/hex/logjam_agent/pull/7)

## 0.5.1

* Fix how channels are instrumented so that parameters that are not a Map are handled gracefully

## 0.5.0

* Add support for Phoenix' Channels and Socket [#4](https://source.xing.com/hex/logjam_agent/pull/4)

## 0.4.0

* Add more accessors to `LogjamAgent.Buffer` [5fcc3ec](https://source.xing.com/hex/logjam_agent/commit/5fcc3ec9248c6be66f47b98aa9afd0f392af9540)
* Use `:hex` format for UUID generation [#3](https://source.xing.com/hex/logjam_agent/pull/3)

## 0.3.0

* Switch to v4 UUIDs

## 0.2.1

* Fix how exbeetle dependency is referenced

## 0.2.0

* Support for AMQP workers [#2](https://source.xing.com/hex/logjam_agent/pull/2)
* Strip root application name form logjam name [#1](https://source.xing.com/hex/logjam_agent/pull/1)


## 0.1.0

* First version with explicit versioning
* Replace AMQP backend with ZMQ (based on ezmq) [#7](https://source.xing.com/architects/logjam_agent.ex/pull/7)
* Fix incorrectly instrumented actions [#9](https://source.xing.com/architects/logjam_agent.ex/pull/9)
