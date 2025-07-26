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
    local title="$1 Database"
    shift
    local menu_options=("$@")
    
    if [[  "$USE_FZF" == true ]]; then
        local selected
        selected=$(printf '%s\n' "${menu_options[@]}" | fzf --header="$title" --height=10 \
        --border --reverse --color=fg:#00ffcc,bg:#1b1b1b,hl:#ffaa00,fg+:#ffffff,bg+:#005f5f,hl+:#ff5f00 \
        --inline-info  --preview='cat {}' --preview-window=right:50%:wrap)
        echo "$selected"
    else
        # Fallback to select
        PS3="Choose an operation: "
        select option in "${menu_options[@]}"; do
            if [[ -n "$option" ]]; then
                echo "$option"
                break
            else
                log "WARNING" "Invalid selection, showing menu again 2"
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
    
    log "INFO" "Entering DQL interface for database '$db_name', table '$table_name'"
    
    # Initial table display
    display_table_data

    while true; do
        log "INFO" "Showing DQL menu options"
        
        local selected_option
        selected_option=$(show_menu_with_fzf "DQL Operations for '$table_name'" "${options[@]}")
        
        
        case "$selected_option" in
            "Filter")
                log "INFO" "User selected Filter operation"
                filter_data
                if [[ -s "$temp_file" ]]; then
                    display_table_data
                fi
                ;;
            "Update")
                log "INFO" "User selected Update operation"
                update_filtered_rows
                if [[ -s "$temp_file" ]]; then
                    display_table_data
                fi
                ;;
            "Delete")
                log "INFO" "User selected Delete operation"
                delete_filtered_rows
                if [[ -s "$temp_file" ]]; then
                    display_table_data
                fi
                ;;
            "Reset Filter")
                log "INFO" "User selected Reset Filter operation"
                reset_filter
                display_table_data
                ;;
            "Back")
                log "INFO" "User selected Back, returning to previous menu"
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
