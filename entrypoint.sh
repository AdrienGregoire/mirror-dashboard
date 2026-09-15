#!/bin/sh
set -e
/app/bin/migrate
exec /app/bin/server