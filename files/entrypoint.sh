#!/usr/bin/env bash
set -eo pipefail

# if command starts with an option, prepend powerdns
if [ "${1:0:1}" = '-' ]; then
	set -- pdns "$@"
fi

exec "$@"