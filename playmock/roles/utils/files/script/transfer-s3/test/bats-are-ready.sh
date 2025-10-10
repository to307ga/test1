#!/usr/bin/env bash

# Fail on unset variables and command errors
set -ue -o pipefail
# Prevent commands misbehaving due to locale differences
export LC_ALL=C

echo "Bats are ready for testing!"

#EOS
