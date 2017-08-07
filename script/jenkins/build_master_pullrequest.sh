#!/bin/sh

set -e

docker-build --target test --tag test-pr .
docker-test docker/compose_build_pullrequests.yml
