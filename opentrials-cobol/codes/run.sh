#!/bin/bash

cd "$(dirname "$0")"

export COB_LIBRARY_PATH="$PWD/bin"

./bin/trial_menu
