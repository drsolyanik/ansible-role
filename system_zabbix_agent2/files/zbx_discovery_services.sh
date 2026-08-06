#!/bin/bash
set -euo pipefail

/bin/systemctl list-unit-files --type=service --no-pager --no-legend \
  | awk '$1 !~ /@/ && $2 != "masked" && $2 != "static" && $2 != "alias" && $2 != "bad" {
      count++
      if (count == 1) printf "["
      else printf ","
      printf "{\"{#SERVICE}\":\"%s\"}", $1
    } END {
      if (count > 0) print "]"
      else print "[]"
    }'
