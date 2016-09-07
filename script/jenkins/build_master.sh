#!/bin/sh

docker build --pull -t hex-logjam-agent-test .

# the redirect works around a bug in the erlang vm: https://github.com/edevil/docker-erlang-bug#explanation
docker run --rm hex-logjam-agent-test bash -c 'mix test 1>&1'
