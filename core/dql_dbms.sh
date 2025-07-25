#!/bin/bash

DQL_DBMS_DIR_PATH="$(dirname "${BASH_SOURCE[0]}")"

source "$DQL_DBMS_DIR_PATH/../lib/validation.sh"
source "$DQL_DBMS_DIR_PATH/../lib/log.sh"

db_name="$1"
table_name="$2"

source "$DQL_DBMS_DIR_PATH/../lib/dql_operations.sh"

function dql_main(){
    local options=("Filter" "Update" "Delete" "Reset Filter" "Back")

    echo -e "\n📋 Full table view of '$table_name':"
    print_header
    print_data "$temp_file"

    while true; do
        echo -e "\nYou are using -> $db_name database, and $table_name table."
        PS3="Choose an operation: "
        select option in "${options[@]}"; do
            case $option in
                "Filter")
                    filter_data
                    break
                    ;;
                "Update")
                    update_filtered_rows
                    break
                    ;;
                "Delete")
                    delete_filtered_rows
                    break
                    ;;
                "Reset Filter")
                    reset_filter
                    echo -e "\n✅ Filter reset. Current table data:"
                    print_header
                    print_data "$temp_file"
                    break
                    ;;
                "Back")
                    echo "Returning to previous menu..."
                    return
                    ;;
                *)
                    echo "Invalid option, try again."
                    ;;
            esac
        done
    done
}

dql_main
