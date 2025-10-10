#!/usr/bin/env bash

# test-all.sh

# Fail on unset variables and command errors
set -ue -o pipefail
# Prevent commands misbehaving due to locale differences
export LC_ALL=C

TEST_PATH=${TEST_PATH:-$(cd "$(dirname "$(realpath "$0")")" && pwd)}

BATS=$TEST_PATH/bats/bin/bats

$BATS "$TEST_PATH"/*.bats

#EOS
