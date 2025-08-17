#!/bin/bash

DQL_OPERATIONS_DIR_PATH="$(dirname "${BASH_SOURCE[0]}")"

base_path="$DQL_OPERATIONS_DIR_PATH/../database/$db_name"
meta_file="$base_path/$table_name.meta"
data_file="$base_path/$table_name"
temp_file="$DQL_OPERATIONS_DIR_PATH/../temp/${table_name}_filtered.tmp"
tmp="$DQL_OPERATIONS_DIR_PATH/../temp/delete_tmp"

DELIM=$'\x1F'

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
function log_filtered_data() {
    mapfile -t meta_lines < "$meta_file"
    local headers=()
    for line in "${meta_lines[@]:1}"; do
        IFS=':' read -r col_name _ <<< "$line"
        headers+=("$col_name")
    done

    local lines_to_log=()

    lines_to_log+=("-----------------------------------------")
   # Data rows
    mapfile -t rows < "$temp_file"  # Read file into array
    for (( i=${#rows[@]}-1; i>=0; i-- )); do  # Loop in reverse
        IFS="$DELIM" read -ra fields <<< "${rows[i]}"
        local data_row="|"
        for f in "${fields[@]}"; do
            data_row+=" $(printf '%-12s' "$f") |"
        done
        lines_to_log+=("$data_row")
    done

    # Header row
    lines_to_log+=("-----------------------------------------")
    local header_row="|"
    for h in "${headers[@]}"; do
        header_row+=" $(printf '%-12s' "$h") |"
    done
    lines_to_log+=("$header_row")

 
    lines_to_log+=("-----------------------------------------")
    lines_to_log+=("Filtered Data from '$table_name':")
    lines_to_log+=("-----------------------------------------")



    log_data "${lines_to_log[@]}"

}


# Function: show field selection with fzf
function select_field_with_fzf() {
    if [[ "$USE_FZF" == true ]]; then
        local preview_cmd="tac \"$DQL_OPERATIONS_DIR_PATH/../logs/dbms.log\" \
            | sed -E 's/(\[ERROR\])/\x1b[31m\1\x1b[0m/; s/(\[INFO\])/\x1b[32m\1\x1b[0m/'"

        local selected
        selected=$(printf '%s\n' "${FIELDS[@]}" | fzf --header="Select field to filter to" --height=100% \
        --border --reverse \
        --color=fg:#c8ccd4,bg:#282c34,hl:#61afef,fg+:#ffffff,bg+:#3e4451,hl+:#98c379 \
        --inline-info \
        --preview="$preview_cmd" \
        --preview-window=right:80%:wrap)
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
    
    local field
    field=$(select_field_with_fzf)
    
    if [[ -z "$field" ]]; then
        log "INFO" "User cancelled field selection"
        return 1
    fi

    # Get field index
    local idx=-1
    for i in "${!FIELDS[@]}"; do
        [[ "${FIELDS[i]}" == "$field" ]] && idx=$((i+1))
    done

    if (( idx == -1 )); then
        log "ERROR" "Invalid field selected: $field"
        return 1
    fi

    # Prompt for operator
    if [[ "$USE_FZF" == true ]]; then
        local preview_cmd="tac \"$DQL_OPERATIONS_DIR_PATH/../logs/dbms.log\" \
        | sed -E 's/(\[ERROR\])/\x1b[31m\1\x1b[0m/; s/(\[INFO\])/\x1b[32m\1\x1b[0m/'"

        operator=$(echo -e "=\n!=\n>\n<\n>=\n<=" | fzf --header="Select operation" --height=100% \
        --border --reverse \
        --color=fg:#c8ccd4,bg:#282c34,hl:#61afef,fg+:#ffffff,bg+:#3e4451,hl+:#98c379 \
        --inline-info \
        --preview="$preview_cmd" \
        --preview-window=right:80%:wrap)
    else
        log "INFO" "Available operators: = != > < >= <="
        read -p "Enter operator: " operator
    fi

    if [[ -z "$operator" ]]; then
        log "ERROR" "No operator selected"
        return 1
    fi

    # Prompt for value
    read -p "Enter value to match: " value

    log "INFO" "Applying filter: '$field''$operator''$value'"

    # Build awk filter expression
    awk_expr=""
    case "$operator" in
        "=")  awk_expr="\$idx == val" ;;
        "!=") awk_expr="\$idx != val" ;;
        ">")  awk_expr="\$idx > val" ;;
        "<")  awk_expr="\$idx < val" ;;
        ">=") awk_expr="\$idx >= val" ;;
        "<=") awk_expr="\$idx <= val" ;;
        *) log "ERROR" "Invalid operator: $operator"; continue ;;
    esac

    awk -F"$DELIM" -v idx="$idx" -v val="$value" "$awk_expr" "$temp_file" > "$tmp" && mv "$tmp" "$temp_file"

    local row_count
    row_count=$(wc -l < "$temp_file")
    log "INFO" "Filter applied, $row_count rows remaining"

    if (( row_count == 0 )); then
        log "ERROR" "No matching rows found after filter"
        return 1
    fi


}

function delete_filtered_rows {

    read -p "Are you sure you want to delete the filtered rows? (y/N): " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        log "INFO" "Delete operation cancelled by user"
        return
    fi

    log "INFO" "Starting delete operation for filtered rows in '$table_name'"
    
    if [[ ! -s "$temp_file" ]]; then
        log "ERROR" "No filtered rows to delete"
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
        log "INFO" "Deleting all the rows in '$table_name'"
        echo "" > $data_file
        return 0
    fi
 
    cp "$data_file" "$temp_file"  # reset temp to reflect delete

    log "INFO" "Successfully deleted $row_count rows from '$table_name'"
}

function update_filtered_rows {
    log "INFO" "Starting update operation for filtered rows in '$table_name'"

    if [[ ! -s "$temp_file" ]]; then
        log "ERROR" "No rows to update"
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


    # Parse field metadata (format: field_name:data_type:nullable:primary_key)
    local data_type=$(echo "$field_metadata" | cut -d: -f2)
    local is_primary=$(echo "$field_metadata" | cut -d: -f3)
    local is_nullable=$(echo "$field_metadata" | cut -d: -f4)

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
        if (( line_count > 1 )); then
            log "ERROR" "Cannot update primary key field '$field' for multiple rows at once"
            return 1
        fi

        if ! validate_primary_key "$new_value" "$is_primary" "$data_file" "$idx" "$field";then
            log "ERROR" "Primary key validation failed for field '$field'"
            return 1
        fi
    fi

       

    log "INFO" "Updating field '$field' to value '$new_value' for filtered rows"

    awk -F"$DELIM" -v OFS="$DELIM" -v col="$((idx+1))" -v val="$new_value" '
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
