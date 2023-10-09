#! /usr/bin/env bash
exec git project cf.sh "*.[ch][ch]" "${1-origin}" "Automatic formatting"
