#!/bin/bash

DML_OPERATIONS_DIR_PATH="$(dirname ${BASH_SOURCE[0]})"

source "$DML_OPERATIONS_DIR_PATH/validation.sh"
source "$DML_OPERATIONS_DIR_PATH/log.sh"



function create_table() {
    local db_name="$1"
    local table_name="$2"
    
    if name_exists "$DML_OPERATIONS_DIR_PATH/../database/$db_name" "$table_name" || ! is_valid_name "$table_name" ; then
        
        log "ERROR" "Table name '$table_name' already exists or is invalid."
        echo "Table name '$table_name' already exists or is invalid."
        return 1
    fi

    touch "$DML_OPERATIONS_DIR_PATH/../database/$db_name/$table_name"
    touch "$DML_OPERATIONS_DIR_PATH/../database/$db_name/$table_name.meta"
    echo "column_name:data_type:is_primary:is_nullable"> "$DML_OPERATIONS_DIR_PATH/../database/$db_name/$table_name.meta"
    local pk=0
    local skip_null=0
    local columns=()
    while true; do
        read -p "Enter column name (or type 'done' to finish): " column_name
        if [[ "$column_name" == "done" ]]; then
            break
        fi

        while ! is_valid_name "$column_name" || [[ " ${columns[@]} " =~ " $column_name:" ]]; do
            log "ERROR" "Invalid or duplicate column name: $column_name. Please enter a unique, valid name."
            echo "Invalid or duplicate column name: $column_name. Please enter a unique, valid name."
            read -p "Enter column name (or type 'done' to finish): " column_name
            if [[ "$column_name" == "done" ]]; then
            return 0
            fi
        done

        read -p "Enter data type for $column_name: (int , string)" data_type
        while [[ "$data_type" != "int" && "$data_type" != "string" ]]; do
            log "ERROR" "Invalid data type: $data_type. Please enter 'int' or 'string'."
            read -p "Enter data type for $column_name: (int , string)" data_type
        done

        local is_primary="no"
        local is_nullable="yes"

        if [[ $pk -eq 0 ]]; then
            read -p "Is $column_name a primary key? (yes/no): " is_primary
            while [[ "$is_primary" != "yes" && "$is_primary" != "no" ]]; do
                log "ERROR" "Invalid input for primary key: $is_primary. Please enter 'yes' or 'no'."
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

    done

    printf "%s\n" "${columns[@]}" >> "$DML_OPERATIONS_DIR_PATH/../database/$db_name/$table_name.meta"
    log "INFO" "Table '$table_name' created successfully in database '$db_name'."

    return 0
}


function drop_table() {
    local db_name="$1"
    local table_name="$2"

    if ! name_exists "$DML_OPERATIONS_DIR_PATH/../database/$db_name" "$table_name"; then
        log "ERROR" "Table '$table_name' does not exist in database '$db_name'."
        echo "Table '$table_name' does not exist in database '$db_name'."
        return 1
    fi

    rm -f "$DML_OPERATIONS_DIR_PATH/../database/$db_name/$table_name"
    rm -f "$DML_OPERATIONS_DIR_PATH/../database/$db_name/$table_name.meta"
    log "INFO" "Table '$table_name' dropped successfully from database '$db_name'."

    return 0
}


function list_tables() {
    local db_name="$1"
    local table_dir="$DML_OPERATIONS_DIR_PATH/../database/$db_name"

    # List only files that do not end with .meta
    local tables=()
    for file in "$table_dir"/*; do
        [[ -f "$file" && "${file##*.}" != "meta" ]] && tables+=("$(basename "$file")")
    done

    if [ ${#tables[@]} -eq 0 ]; then
        log "INFO" "No tables found in database '$db_name'."
        echo "No tables found in database '$db_name'."
        return 0
    fi

    echo "Tables in database '$db_name':"
    for table in "${tables[@]}"; do
        echo "$table"
    done

    return 0
}


function table_info() {
    local db_name="$1"
    local table_name="$2"
    local base_path="$DML_OPERATIONS_DIR_PATH/../database/$db_name"
    local meta_file="$base_path/$table_name.meta"
    local data_file="$base_path/$table_name"

    if ! name_exists "$base_path" "$table_name"; then
        log "ERROR" "Table '$table_name' does not exist in database '$db_name'."
        echo "Table '$table_name' does not exist in database '$db_name'."
        return 1
    fi

    if [[ ! -f "$meta_file" || ! -f "$data_file" ]]; then
        echo "Metadata or data file is missing for table '$table_name'."
        return 1
    fi

    # Count columns and rows
    local column_count
    column_count=$(awk 'NR>1 {c++} END {print c+0}' "$meta_file")
    local row_count
    row_count=$(wc -l < "$data_file")

    echo "Table: $table_name"
    echo "Columns: $column_count | Rows: $row_count"
    echo "---------------------------------------------"
    echo "🔹 Column Details:"
    echo

    awk -F: 'NR==1 { next } 
    {
        printf "- %-15s | Type: %-6s | Primary Key: %-3s | Nullable: %-3s\n", $1, $2, $3, $4
    }' "$meta_file"

    echo "---------------------------------------------"
    return 0
}

insert_row() {
    local db_name="$1"
    local table_name="$2"
    local base_path="$DML_OPERATIONS_DIR_PATH/../database/$db_name"
    local meta_file="$base_path/$table_name.meta"
    local data_file="$base_path/$table_name"

    # take meta data infromations inside columns array
    mapfile -t columns < <(awk -F: 'NR>1 {print $1 ":" $2 ":" $3 ":" $4}' "$meta_file")

    local insert_values=()
    local index=0

    for column in "${columns[@]}"; do
        IFS=':' read -r column_name data_type is_primary is_nullable <<< "$column"
        
        while true; do
            read -p "Enter value for $column: " value

            # Nullable check
            validate_nullable "$value" "$is_nullable" "$column_name"
            if [[ $? -ne 0 ]]; then continue; fi
            [[ "$value" == "NULL" || -z "$value" ]] && insert_values+=(" ") && break
            log "passed nullable check for $column_name with value: $value"
            # Data type check
            validate_data_type "$value" "$data_type" "$column_name"
            [[ $? -ne 0 ]] && continue
            log "passed data type check for $column_name with value: $value"
            # Primary key check
            validate_primary_key "$value" "$is_primary" "$data_file" "$index" "$column_name"
            [[ $? -ne 0 ]] && continue
            log "passed primary key check for $column_name with value: $value"
            # All passed
            insert_values+=("$value")
            break
        done

        ((index++))
    done

    IFS=':'; echo "${insert_values[*]}" >> "$data_file"; unset IFS
    log "INFO" "Data inserted successfully into table '$table_name'."
    return 0
}
