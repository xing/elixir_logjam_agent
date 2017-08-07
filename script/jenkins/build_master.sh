#!/bin/sh

set -e

docker-build --target test --tag test-latest .
docker-test docker/compose_build_master.yml
