#!/bin/sh

response=$(
    SCRIPT_NAME=/ping \
    SCRIPT_FILENAME=/ping \
    REQUEST_URI=/ping \
    REQUEST_METHOD=GET \
    cgi-fcgi -bind -connect 127.0.0.1:9000 2>/dev/null
) || exit 1

printf '%s\n' "$response" | grep -q 'pong'
