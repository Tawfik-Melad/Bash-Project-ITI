#!/bin/bash

DQL_OPERATIONS_DIR_PATH="$(dirname "${BASH_SOURCE[0]}")"

base_path="$DQL_OPERATIONS_DIR_PATH/../database/$db_name"
meta_file="$base_path/$table_name.meta"
data_file="$base_path/$table_name"
temp_file="$DQL_OPERATIONS_DIR_PATH/../temp/${table_name}_filtered.tmp"
tmp="$DQL_OPERATIONS_DIR_PATH/../temp/delete_tmp"

source "$DQL_OPERATIONS_DIR_PATH/validation.sh"
source "$DQL_OPERATIONS_DIR_PATH/log.sh"

# Extract column names from metadata
mapfile -t FIELDS < <(tail -n +2 "$meta_file" | cut -d: -f1)

# Initialize filtered data file
cp "$data_file" "$temp_file"

# Check if fzf is available
if ! command -v fzf &> /dev/null; then
    USE_FZF=false
else
    USE_FZF=true
fi

# Function: reset filter to full table
function reset_filter {
    log "INFO" "Resetting filter for table '$table_name'"
    cp "$data_file" "$temp_file"
}

# Function: print header
function print_header {
    echo ""
    for i in "${!FIELDS[@]}"; do
        printf "| %-15s " "${FIELDS[i]}"
    done
    echo -e "|\n$(printf '=%.0s' {1..100})"
}

# Function: print data rows
function print_data {
    awk -F: '
        {
            printf "| %-15s", $1;
            for (i = 2; i <= NF; i++) {
                printf "| %-15s", $i;
            }
            print " |"
        }
    ' "$1"
}

# Function: show field selection with fzf
function select_field_with_fzf() {
    if [[ "$USE_FZF" == true ]]; then
        local selected
        selected=$(printf '%s\n' "${FIELDS[@]}" | fzf --header="Select field to filter" --height=8 --reverse --border)
        echo "$selected"
    else
        # Fallback to simple selection
        echo "Available fields: ${FIELDS[*]}"
        read -p "Enter field name: " field
        echo "$field"
    fi
}

# Function: filter data based on user input
function filter_data {
    log "INFO" "Starting filter operation for table '$table_name'"
    
    while true; do
        local field
        field=$(select_field_with_fzf)
        
        if [[ -z "$field" ]]; then
            log "INFO" "User cancelled field selection"
            break
        fi

        # Get field index
        local idx=-1
        for i in "${!FIELDS[@]}"; do
            [[ "${FIELDS[i]}" == "$field" ]] && idx=$((i+1))
        done

        if (( idx == -1 )); then
            log "WARNING" "Invalid field selected: $field"
            continue
        fi

        read -p "Enter value to match: " value
        if [[ -z "$value" ]]; then
            log "WARNING" "Empty value provided for filtering"
            continue
        fi

        log "INFO" "Applying filter: field='$field', value='$value'"
        awk -F: -v idx="$idx" -v val="$value" '$idx == val' "$temp_file" > "$tmp" && mv "$tmp" "$temp_file"

        local row_count
        row_count=$(wc -l < "$temp_file")
        log "INFO" "Filter applied, $row_count rows remaining"

        if (( row_count == 0 )); then
            log "WARNING" "No matching rows found after filter"
            break
        fi

        # Ask if user wants to apply another filter
        if [[ "$USE_FZF" == true ]]; then
            local continue_filter
            continue_filter=$(echo -e "Yes\nNo" | fzf --header="Apply another filter?" --height=5 --reverse --border)
            [[ "$continue_filter" != "Yes" ]] && break
        else
            read -p "Apply another filter? (y/n): " continue_filter
            [[ "$continue_filter" != "y" && "$continue_filter" != "Y" ]] && break
        fi
    done
}

function delete_filtered_rows {
    log "INFO" "Starting delete operation for filtered rows in '$table_name'"
    
    if [[ ! -s "$temp_file" ]]; then
        log "WARNING" "No filtered rows to delete"
        return
    fi

    local row_count
    row_count=$(wc -l < "$temp_file")
    log "INFO" "Preparing to delete $row_count filtered rows"

    # Backup before delete
    cp "$data_file" "${data_file}.bak"
    log "INFO" "Created backup: ${data_file}.bak"

    # Delete matching lines from main file

    grep -v -F -x -f "$temp_file" "$data_file" > "$tmp" && mv "$tmp" "$data_file"
    if [[ $? -ne 0 ]]; then
        log "deleting all the data in the table"
        echo "" > $data_file
        return 0
    fi
 
    echo "data_file: $data_file"
    cp "$data_file" "$temp_file"  # reset temp to reflect delete

    log "INFO" "Successfully deleted $row_count rows from '$table_name'"
}

function update_filtered_rows {
    log "INFO" "Starting update operation for filtered rows in '$table_name'"

    if [[ ! -s "$temp_file" ]]; then
        log "WARNING" "No rows to update"
        return
    fi

    local field
    field=$(select_field_with_fzf)
    
    if [[ -z "$field" ]]; then
        log "INFO" "User cancelled field selection for update"
        return
    fi

    # Get field index and metadata
    local idx=-1
    local field_metadata=""
    for i in "${!FIELDS[@]}"; do
        if [[ "${FIELDS[i]}" == "$field" ]]; then
            idx=$i
            # Get field metadata from the meta file (line number = i + 2, since first line is header)
            field_metadata=$(sed -n "$((i+2))p" "$meta_file")
            break
        fi
    done

    if (( idx == -1 )); then
        log "ERROR" "Invalid field name: $field"
        return
    fi


    echo $field_metadata
    # Parse field metadata (format: field_name:data_type:nullable:primary_key)
    local data_type=$(echo "$field_metadata" | cut -d: -f2)
    local is_primary=$(echo "$field_metadata" | cut -d: -f3)
    local is_nullable=$(echo "$field_metadata" | cut -d: -f4)

    echo "here -> $data_type $is_primary $field"
    log "INFO" "Field '$field' metadata: data_type=$data_type, nullable=$is_nullable, primary=$is_primary"

    read -p "Enter the new value for field '$field': " new_value
    
    # 1. Validate nullable constraint first
    if ! validate_nullable "$new_value" "$is_nullable" "$field"; then
        log "ERROR" "Validation failed for field '$field'"
        return 1
    fi

    # 2. If the field is NOT nullable, validate the data type (i.e., only when it's required to have a value)
    if [[ "$is_nullable" == "no" ]]; then
        if ! validate_data_type "$new_value" "$data_type" "$field"; then
            log "ERROR" "Validation failed for field '$field'"
            return 1
        fi
    fi

    # 3. OR: If the value is NOT empty, validate data type anyway (e.g., optional field but user entered something)
    if [[ -n "$new_value" ]]; then
        if ! validate_data_type "$new_value" "$data_type" "$field"; then
            log "ERROR" "Validation failed for field '$field'"
            return 1
        fi
    fi

    if [[ "$is_primary" == "yes" ]]; then

        local line_count
        line_count=$(wc -l < "$temp_file")
        echo "HI ----------> $line_count"
        if (( line_count > 1 )); then
            echo "Error: you trying to update ($line_count) row with the same value for primary feild"
            return 1
        fi
        validate_primary_key "$new_value" "$is_primary" "$data_file" "$idx" "$field"
    fi

       

    log "INFO" "Updating field '$field' to value '$new_value' for filtered rows"

    awk -F: -v OFS=: -v col="$((idx+1))" -v val="$new_value" '
    BEGIN {
        while ((getline line < "'$temp_file'") > 0) {
            filtered[line] = 1
        }
        close("'$temp_file'")
    }
    {
        orig = $0
        if (orig in filtered) {
            $col = val
            print
        } else {
            print
        }
    }
    ' "$data_file" > tmp && mv tmp "$data_file"

    cp "$data_file" "$temp_file"  # update temp as well

    log "INFO" "Successfully updated filtered rows in '$table_name'"
}
