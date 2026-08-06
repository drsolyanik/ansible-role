#!/bin/bash

service="$1"
metric="$2"

pid=$(systemctl show -p MainPID --value "$service")

if [[ -z "$pid" || "$pid" -eq 0 ]]; then
    case "$metric" in
        state)
            if systemctl show "$service" >/dev/null 2>&1; then
                systemctl is-active "$service" 2>/dev/null
            else
                echo "unknown"
            fi
            ;;
        type)
            if systemctl show "$service" >/dev/null 2>&1; then
                val=$(systemctl show -p Type --value "$service" 2>/dev/null)
                [[ -n "$val" ]] && echo "$val"
            else
                echo "unknown"
            fi
            ;;
        cpu|mem)
            echo 0
            ;;
        *)
            echo "unknown"
            ;;
    esac
    exit 0
fi

case "$metric" in
    state)
        systemctl is-active "$service" 2>/dev/null || echo "unknown"
        ;;
    type)
        systemctl show -p Type --value "$service" 2>/dev/null || echo "unknown"
        ;;
    cpu)
        LC_ALL=C ps -p "$pid" -o %cpu= | LC_ALL=C awk '{printf "%.2f\n", $1}'
        ;;
    mem)
        LC_ALL=C ps -p "$pid" -o rss= | LC_ALL=C awk '{printf "%.2f\n", $1*1024}'
        ;;
    *)
        echo "unknown"
        ;;
esac
