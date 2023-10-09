#! /usr/bin/env bash
exec clang-format -i --style=file -- "$@"
