#!/bin/bash

DQL_OPERATIONS_DIR_PATH="$(dirname "${BASH_SOURCE[0]}")"

base_path="$DQL_OPERATIONS_DIR_PATH/../database/$db_name"
meta_file="$base_path/$table_name.meta"
data_file="$base_path/$table_name"
temp_file="$DQL_OPERATIONS_DIR_PATH/../temp/${table_name}_filtered.tmp"

source "$DQL_OPERATIONS_DIR_PATH/validation.sh"
source "$DQL_OPERATIONS_DIR_PATH/log.sh"

# Extract column names from metadata
mapfile -t FIELDS < <(tail -n +2 "$meta_file" | cut -d: -f1)

# Initialize filtered data file
cp "$data_file" "$temp_file"

# Function: reset filter to full table
function reset_filter {
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

# Function: filter data based on user input
function filter_data {
    log "INFO" "Filtering data in table '$table_name'."
    while true; do
        echo -e "\nAvailable fields: ${FIELDS[@]}"
        read -p "Enter field to filter (or 'done' to stop): " field
        [[ "$field" == "done" ]] && break

        # Get field index
        idx=-1
        for i in "${!FIELDS[@]}"; do
            [[ "${FIELDS[i]}" == "$field" ]] && idx=$((i+1))
        done

        if (( idx == -1 )); then
            echo "Invalid field."
            continue
        fi

        read -p "Enter value to match: " value
        awk -F: -v idx="$idx" -v val="$value" '$idx == val' "$temp_file" > tmp && mv tmp "$temp_file"

        echo -e "\nFiltered result:"
        print_header
        print_data "$temp_file"

        if (( $(wc -l < "$temp_file") == 0 )); then
            echo -e "\n⚠️  No matching rows left."
            break
        fi

        break  # Apply only one filter at a time
    done
}


function delete_filtered_rows {
    log "INFO" "Deleting filtered rows from '$table_name'."
    
    if [[ ! -s "$temp_file" ]]; then
        echo "❌ No filtered rows to delete."
        return
    fi

    # Backup before delete (optional)
    cp "$data_file" "${data_file}.bak"

    # Delete matching lines from main file
    grep -v -F -x -f "$temp_file" "$data_file" > tmp && mv tmp "$data_file"
    cp "$data_file" "$temp_file"  # reset temp to reflect delete

    echo -e "\n🗑️ Deleted rows. Updated table:"
    print_header
    print_data "$temp_file"
}


function update_filtered_rows {
    log "INFO" "Updating filtered rows in '$table_name'."

    if [[ ! -s "$temp_file" ]]; then
        echo "❌ No rows to update."
        return
    fi

    echo -e "\nAvailable fields: ${FIELDS[@]}"
    read -p "Enter the field to update: " field_name
    idx=-1
    for i in "${!FIELDS[@]}"; do
        [[ "${FIELDS[i]}" == "$field_name" ]] && idx=$i
    done

    if (( idx == -1 )); then
        echo "Invalid field name."
        return
    fi

    read -p "Enter the new value for field '$field_name': " new_value

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

    echo -e "\n✅ Updated table:"
    print_header
    print_data "$temp_file"
}
