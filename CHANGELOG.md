# Changelog

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
