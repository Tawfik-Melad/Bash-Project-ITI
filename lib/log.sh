#!/bin/bash
LOG_DIR_PATH="$(dirname ${BASH_SOURCE[0]})"

LOG_FILE="$LOG_DIR_PATH/../logs/dbms.log"

log() {
    local level="$1"
    local message="$2"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
}
