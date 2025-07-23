#!/bin/bash

DDL_OPERATIONS_DIR_PATH="$(dirname ${BASH_SOURCE[0]})"

source "$DDL_OPERATIONS_DIR_PATH/validation.sh"
source "$DDL_OPERATIONS_DIR_PATH/log.sh"

function create_database() {

    local db_name="$1"
    if ! is_valid_name "$db_name" || name_exists "$DDL_OPERATIONS_DIR_PATH/../database" "$db_name"  ; then
        echo "Invalid database name. Check logs for details."
        log "ERROR" "Invalid database name '$db_name' or it already exists."
        return 1
    fi
    mkdir -p "$DDL_OPERATIONS_DIR_PATH/../database/$db_name"
    log "INFO" "Database '$db_name' created successfully."
    echo "Database '$db_name' created successfully enter 4 to connect to it."
    return 0

}

function delete_database() {
    local db_name="$1"
    if ! name_exists "$DDL_OPERATIONS_DIR_PATH/../database" "$db_name"; then
        echo "Database '$db_name' does not exist."
        log "ERROR" "Database '$db_name' does not exist."
        return 1
    fi

    echo "Are you sure you want to delete the database '$db_name'? (yes/no)"
    read confirmation
    if [[ "$confirmation" != "yes" ]]; then
        echo "Deletion cancelled."
        log "INFO" "Deletion of database '$db_name' cancelled."
        return 0
    fi
    rm -rf "$DDL_OPERATIONS_DIR_PATH/../database/$db_name"
    log "INFO" "Database '$db_name' deleted successfully."
    echo "Database '$db_name' deleted successfully."
    return 0
}

function connect_to_database() {
    local db_name="$1"
    if  name_exists "$DDL_OPERATIONS_DIR_PATH/../database" "$db_name"; then
        echo "Connecting to database '$db_name'..."
        log "INFO" "Connecting to database '$db_name'."
        
        return 0
    else
        log "ERROR" "Database '$db_name' does not exist."
        echo "Database '$db_name' does not exist."
        return 1
    fi
}