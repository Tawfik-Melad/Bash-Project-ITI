#!/bin/bash

DQL_DBMS_DIR_PATH="$(dirname "${BASH_SOURCE[0]}")"

source "$DQL_DBMS_DIR_PATH/../lib/validation.sh"
source "$DQL_DBMS_DIR_PATH/../lib/log.sh"

db_name="$1"
table_name="$2"

source "$DQL_DBMS_DIR_PATH/../lib/dql_operations.sh"

# Check if fzf is available
if ! command -v fzf &> /dev/null; then
    log "WARNING" "fzf not found, falling back to select menu"
    USE_FZF=false
else
    USE_FZF=true
fi

function show_menu_with_fzf() {
    local title="$1"
    shift
    local menu_options=("$@")

    if [[ "$USE_FZF" == true ]]; then
        local preview_cmd="tail -n 50 \"$DQL_DBMS_DIR_PATH/../logs/dbms.log\" \
            | tac \
            | sed -E 's/(\[ERROR\])/\x1b[31m\1\x1b[0m/; s/(\[INFO\])/\x1b[32m\1\x1b[0m/'"

        local selected
        selected=$(printf '%s\n' "${menu_options[@]}" | fzf --header="$title" --height=25 \
        --border --reverse \
        --color=fg:#c8ccd4,bg:#282c34,hl:#61afef,fg+:#ffffff,bg+:#3e4451,hl+:#98c379 \
        --inline-info \
        --preview="$preview_cmd" \
        --preview-window=right:80%:wrap)
        echo "$selected"
    else
        PS3="Choose an operation: "
        select option in "${menu_options[@]}"; do
            if [[ -n "$option" ]]; then
                echo "$option"
                break
            else
                log "WARNING" "Invalid selection, Trying again"
                echo ""
                break
            fi
        done
    fi
}

function display_table_data() {
    log "INFO" "Displaying table data for '$table_name'"
    print_header
    print_data "$temp_file"
}

function dql_main(){
    local options=("Filter" "Update" "Delete" "Reset Filter" "Back")
    
    log "INFO" "You using database '$db_name', table '$table_name'"
    
    # Initial table display
    display_table_data

    while true; do
        
        local selected_option
        selected_option=$(show_menu_with_fzf "DQL Operations for '$table_name'" "${options[@]}")
        
        
        case "$selected_option" in
            "Filter")
                log "INFO" "Filtering data in table '$table_name' ..."
                filter_data
                display_table_data
                ;;
            "Update")
                log "INFO" "Updating data in table '$table_name' ..."
                update_filtered_rows
                display_table_data
                ;;
            "Delete")
                log "INFO" "Deleting data in table '$table_name' ..."
                delete_filtered_rows
                display_table_data
                ;;
            "Reset Filter")
                log "INFO" "Resetting filter for table '$table_name' ..."
                reset_filter
                display_table_data
                ;;
            "Back")
                echo "" > $DQL_DBMS_DIR_PATH/../logs/dbms.log
                return 0
                ;;
            *)
                log "WARNING" "Invalid option selected: $selected_option"
                continue
                ;;
        esac
    done
}

dql_main
