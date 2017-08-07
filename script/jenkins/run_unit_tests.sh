#!/bin/sh

set -e

echo -e "\n\n\nTESTS:\n"
mkdir -p "test/tmp"
mix test

echo -e "\n\n\nCREDO:\n"
mix credo suggest --all --format oneline

