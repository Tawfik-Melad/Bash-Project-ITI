#!/bin/bash

DML_OPERATIONS_DIR_PATH="$(dirname ${BASH_SOURCE[0]})"

source "$DML_OPERATIONS_DIR_PATH/validation.sh"
source "$DML_OPERATIONS_DIR_PATH/log.sh"

function create_table() {
    local db_name="$1"
    local table_name="$2"
    
    if name_exists "$DML_OPERATIONS_DIR_PATH/../database/$db_name" "$table_name" || ! is_valid_name "$table_name" ; then
        log "ERROR" "Table name '$table_name' already exists or is invalid."
        return 1
    fi

    touch "$DML_OPERATIONS_DIR_PATH/../database/$db_name/$table_name"
    touch "$DML_OPERATIONS_DIR_PATH/../database/$db_name/$table_name.meta"
    echo "column_name:data_type:is_primary:is_nullable"> "$DML_OPERATIONS_DIR_PATH/../database/$db_name/$table_name.meta"
    local pk=0
    local skip_null=0
    local columns=()
    
    log "INFO" "Starting table creation for '$table_name' in database '$db_name'"
    
    while true; do
        read -p "Enter column name (or type 'done' to finish): " column_name
        if [[ "$column_name" == "done" ]]; then
            break
        fi

        while ! is_valid_name "$column_name" || [[ " ${columns[@]} " =~ " $column_name:" ]]; do
            log "ERROR" "Invalid or duplicate column name: $column_name"
            read -p "Enter column name (or type 'done' to finish): " column_name
            if [[ "$column_name" == "done" ]]; then
                return 0
            fi
        done

        read -p "Enter data type for $column_name: (int , string)" data_type
        while [[ "$data_type" != "int" && "$data_type" != "string" ]]; do
            log "ERROR" "Invalid data type: $data_type"
            read -p "Enter data type for $column_name: (int , string)" data_type
        done

        local is_primary="no"
        local is_nullable="yes"

        if [[ $pk -eq 0 ]]; then
            read -p "Is $column_name a primary key? (yes/no): " is_primary
            while [[ "$is_primary" != "yes" && "$is_primary" != "no" ]]; do
                log "ERROR" "Invalid input for primary key: $is_primary"
                read -p "Is $column_name a primary key? (yes/no): " is_primary
            done
            if [[ "$is_primary" == "yes" ]]; then
                pk=1 # mark that primary key is set and don't ask again
                is_nullable="no" # primary key cannot be nullable    
            fi
        fi

        if [[ $is_nullable != "no" ]]; then # don't ask if it is primary key
            read -p "Is $column_name nullable? (yes/no): " is_nullable
            while [[ "$is_nullable" != "yes" && "$is_nullable" != "no" ]]; do
                log "ERROR" "Invalid input for nullable: $is_nullable"
                read -p "Is $column_name nullable? (yes/no): " is_nullable
                continue
            done
        fi

        columns+=("$column_name:$data_type:$is_primary:$is_nullable")
        log "INFO" "Added column '$column_name' to table '$table_name'"
    done

    printf "%s\n" "${columns[@]}" >> "$DML_OPERATIONS_DIR_PATH/../database/$db_name/$table_name.meta"
    log "INFO" "Table '$table_name' created successfully in database '$db_name' with ${#columns[@]} columns"

    return 0
}

function drop_table() {
    local db_name="$1"
    local table_name="$2"

    if ! name_exists "$DML_OPERATIONS_DIR_PATH/../database/$db_name" "$table_name"; then
        log "ERROR" "Table '$table_name' does not exist in database '$db_name'"
        return 1
    fi

    rm -f "$DML_OPERATIONS_DIR_PATH/../database/$db_name/$table_name"
    rm -f "$DML_OPERATIONS_DIR_PATH/../database/$db_name/$table_name.meta"
    log "INFO" "Table '$table_name' dropped successfully from database '$db_name'"

    return 0
}

function list_tables() {
    local db_name="$1"
    local db_path="$DML_OPERATIONS_DIR_PATH/../database/$db_name"
    
    if [[ ! -d "$db_path" ]]; then
        log "ERROR" "Database '$db_name' does not exist"
        return 1
    fi
    
    local tables
    tables=$(find "$db_path" -maxdepth 1 -type f -name "*.meta" -exec basename {} .meta \; 2>/dev/null | sort)
    
    if [[ -z "$tables" ]]; then
        log "INFO" "No tables found in database '$db_name'"
    else
        log "INFO" "Tables in database '$db_name': $tables"
    fi
}

function table_info() {
    local db_name="$1"
    local table_name="$2"
    local meta_file="$DML_OPERATIONS_DIR_PATH/../database/$db_name/$table_name.meta"
    local data_file="$DML_OPERATIONS_DIR_PATH/../database/$db_name/$table_name"

    if ! name_exists "$DML_OPERATIONS_DIR_PATH/../database/$db_name" "$table_name"; then
        log "ERROR" "Table '$table_name' does not exist in database '$db_name'"
        return 1
    fi

    if [[ ! -f "$meta_file" || ! -f "$data_file" ]]; then
        log "ERROR" "Metadata or data file is missing for table '$table_name'"
        return 1
    fi

    local column_count
    column_count=$(tail -n +2 "$meta_file" | wc -l)
    local row_count
    row_count=$(wc -l < "$data_file")

    log "INFO" "Table info for '$table_name': $column_count columns, $row_count rows"
    
    # Display table info for user
    echo "Table: $table_name"
    echo "Columns: $column_count | Rows: $row_count"
    echo "---------------------------------------------"
    echo "🔹 Column Details:"
    echo
    
    tail -n +2 "$meta_file" | while IFS=':' read -r col_name data_type is_primary is_nullable; do
        echo "  • $col_name ($data_type)"
        if [[ "$is_primary" == "yes" ]]; then
            echo "    Primary Key: Yes"
        fi
        if [[ "$is_nullable" == "no" ]]; then
            echo "    Nullable: No"
        fi
        echo
    done
    
    echo "---------------------------------------------"
}

function insert_row() {
    local db_name="$1"
    local table_name="$2"
    local meta_file="$DML_OPERATIONS_DIR_PATH/../database/$db_name/$table_name.meta"
    local data_file="$DML_OPERATIONS_DIR_PATH/../database/$db_name/$table_name"

    if ! name_exists "$DML_OPERATIONS_DIR_PATH/../database/$db_name" "$table_name"; then
        log "ERROR" "Table '$table_name' does not exist in database '$db_name'"
        return 1
    fi

    if [[ ! -f "$meta_file" ]]; then
        log "ERROR" "Metadata file missing for table '$table_name'"
        return 1
    fi

    log "INFO" "Starting row insertion for table '$table_name'"

    # Read column definitions
    mapfile -t columns < <(tail -n +2 "$meta_file")
    local insert_values=()

    for column in "${columns[@]}"; do
        IFS=':' read -r col_name data_type is_primary is_nullable <<< "$column"
        
        while true; do
            read -p "Enter value for $col_name ($data_type): " value
            
            # Validate primary key uniqueness
            if [[ "$is_primary" == "yes" ]]; then
                if grep -q "^$value:" "$data_file" 2>/dev/null; then
                    log "ERROR" "Primary key value '$value' already exists"
                    continue
                fi
            fi
            
            # Validate data type
            if [[ "$data_type" == "int" ]]; then
                if ! [[ "$value" =~ ^[0-9]+$ ]]; then
                    log "ERROR" "Invalid integer value: $value"
                    continue
                fi
            fi
            
            # Check nullable constraint
            if [[ -z "$value" && "$is_nullable" == "no" ]]; then
                log "ERROR" "Column '$col_name' cannot be null"
                continue
            fi
            
            insert_values+=("$value")
            break
        done
    done

    IFS=':'; echo "${insert_values[*]}" >> "$data_file"; unset IFS
    log "INFO" "Successfully inserted row into table '$table_name'"
}
