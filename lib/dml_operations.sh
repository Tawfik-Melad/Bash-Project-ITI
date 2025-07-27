#!/bin/bash

DML_OPERATIONS_DIR_PATH="$(dirname ${BASH_SOURCE[0]})"

source "$DML_OPERATIONS_DIR_PATH/validation.sh"
source "$DML_OPERATIONS_DIR_PATH/log.sh"

function create_table() {
    local db_name="$1"
    local table_name="$2"
    
    if name_exists "$DML_OPERATIONS_DIR_PATH/../database/$db_name" "$table_name" || ! is_valid_name "$table_name" ; then
        log "ERROR" "Failed to create table '$table_name' in database '$db_name'."
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
            echo "Invalid or duplicate column name: $column_name"
            read -p "Enter column name (or type 'done' to finish): " column_name
            if [[ "$column_name" == "done" ]]; then
                return 0
            fi
        done

        read -p "Enter data type for $column_name: (int , string)" data_type
        while [[ "$data_type" != "int" && "$data_type" != "string" ]]; do
            log "ERROR" "Invalid data type: $data_type"
            echo "Invalid data type: $data_type"
            read -p "Enter data type for $column_name: (int , string)" data_type
        done

        local is_primary="no"
        local is_nullable="yes"

        if [[ $pk -eq 0 ]]; then
            read -p "Is $column_name a primary key? (yes/no): " is_primary
            while [[ "$is_primary" != "yes" && "$is_primary" != "no" ]]; do
                log "ERROR" "Invalid input for primary key: $is_primary"
                echo "Invalid input for primary key: $is_primary"
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
                echo "Invalid input for nullable: $is_nullable"
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
        log_data $tables
        log "INFO" "📝 Tables in database '$db_name': "
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

    local column_count row_count
    column_count=$(tail -n +2 "$meta_file" | wc -l)
    row_count=$(wc -l < "$data_file")

    local lines=()

    lines+=("+-------------------+-------------+-------------+----------+")
    lines+=("| Column Name       | Data Type   | Primary Key | Nullable |")
    lines+=("+-------------------+-------------+-------------+----------+")

    while IFS=':' read -r col_name data_type is_primary is_nullable; do
        local line="| $(printf '%-17s' "$col_name") | $(printf '%-11s' "$data_type") | $(printf '%-11s' "$is_primary") | $(printf '%-8s' "$is_nullable") |"
        lines+=("$line")
    done < <(tail -n +2 "$meta_file")

    lines+=("+-------------------+-------------+-------------+----------+")
    lines+=("")
    lines+=("📊 Columns: $column_count   🧾 Rows: $row_count")
    lines+=("📂 Table: $table_name")

    # Show to user
    for line in "${lines[@]}"; do
        echo -e "$line"
    done

    # Log in reverse order for `tac`-based preview
    for (( idx=${#lines[@]}-1 ; idx>=0 ; idx-- )); do
        log_data "${lines[idx]}"
    done
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

    # Ensure data file exists
    touch "$data_file"

    log "INFO" "Starting row insertion for table '$table_name'"

    # Read column definitions
    mapfile -t columns < <(tail -n +2 "$meta_file")
    local insert_values=()

    for i in "${!columns[@]}"; do
        IFS=':' read -r col_name data_type is_primary is_nullable <<< "${columns[i]}"
        
        while true; do
            read -p "Enter value for $col_name ($data_type): " value
            
            # Check nullable constraint
            if [[ -z "$value" ]]; then
                if [[ "$is_nullable" == "no" ]]; then
                    echo "❌ Column '$col_name' cannot be null"
                    log "ERROR" "Null value not allowed for column '$col_name'"
                    continue
                fi
                insert_values+=("")  # true empty
                break
            fi

            # Validate data type
            if [[ "$data_type" == "int" ]]; then
                if ! [[ "$value" =~ ^-?[0-9]+$ ]]; then
                    echo "❌ Invalid integer value: $value"
                    log "ERROR" "Invalid integer for '$col_name': $value"
                    continue
                fi
            fi

            # Validate primary key uniqueness (check correct column)
            if [[ "$is_primary" == "yes" ]]; then
                pk_index=$i
                existing_values=$(cut -d: -f$((pk_index+1)) "$data_file")

                if echo "$existing_values" | grep -Fxq "$value"; then
                    echo "❌ Primary key value '$value' already exists"
                    log "ERROR" "Duplicate primary key '$value' for column '$col_name'"
                    continue
                fi
            fi

            insert_values+=("$value")
            break
        done
    done

    IFS=':'; echo "${insert_values[*]}" >> "$data_file"; unset IFS
    echo "✅ Row inserted successfully."
    log "INFO" "Successfully inserted row into table '$table_name'"
}
