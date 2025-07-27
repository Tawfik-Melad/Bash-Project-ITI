#!/bin/bash

DDL_OPERATIONS_DIR_PATH="$(dirname ${BASH_SOURCE[0]})"

source "$DDL_OPERATIONS_DIR_PATH/validation.sh"
source "$DDL_OPERATIONS_DIR_PATH/log.sh"

function create_database() {
    local db_name="$1"
    
    if ! is_valid_name "$db_name" || name_exists "$DDL_OPERATIONS_DIR_PATH/../database" "$db_name"; then
        log "ERROR" "Failed to create database '$db_name' "
        return 1
    fi
    
    mkdir -p "$DDL_OPERATIONS_DIR_PATH/../database/$db_name"
    log "INFO" "Database '$db_name' created successfully"
    return 0
}

function delete_database() {
    local db_name="$1"
    
    if ! name_exists "$DDL_OPERATIONS_DIR_PATH/../database" "$db_name"; then
        log "ERROR" "Database '$db_name' does not exist"
        return 1
    fi

    read -p "Are you sure you want to delete the database '$db_name'? (yes/no): " confirmation
    if [[ "$confirmation" != "yes" ]]; then
        log "INFO" "You cancelled deletion database '$db_name' "
        return 0
    fi
    
    rm -rf "$DDL_OPERATIONS_DIR_PATH/../database/$db_name"
    log "INFO" "Database '$db_name' deleted successfully"
    return 0
}

function connect_to_database() {
    local db_name="$1"
    
    if name_exists "$DDL_OPERATIONS_DIR_PATH/../database" "$db_name"; then
        return 0
    else
        return 1
    fi
}