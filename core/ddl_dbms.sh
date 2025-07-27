#!/bin/bash
DDL_DBMS_DIR_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$DDL_DBMS_DIR_PATH/../lib/validation.sh"
source "$DDL_DBMS_DIR_PATH/../lib/log.sh"
source "$DDL_DBMS_DIR_PATH/../lib/ddl_operations.sh"

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

function ddl_main(){
    log "INFO" "Entering DDL interface"
    
    while true; do
        local options=("Create Database" "Drop Database" "List Databases" "Connect to Database" "Exit")
        log "INFO" "Showing DDL menu options"
        
        local selected_option
        selected_option=$(show_menu_with_fzf "DDL Opedfsadfdrations" "${options[@]}")

        
        case "$selected_option" in
            "Create Database")
                log "INFO" "User selected Create Database operation"
                read -p "Enter the database name to create: " db_name
                create_database "$db_name"

                ;;
            "Drop Database")
                log "INFO" "User selected Drop Database operation"
                read -p "Enter the database name to drop: " db_name
                delete_database "$db_name"

                ;;
            "List Databases")
                log "INFO" "User selected List Databases operation"
                    local databases
                    databases=$(ls -1 "$DDL_DBMS_DIR_PATH/../database" 2>/dev/null)
                    echo -e "\n📂 Available Databases:"
                    echo "$databases"
                ;;
            "Connect to Database")
                log "INFO" "User selected Connect to Database operation"
                read -p "Enter the database name to connect: " db_name
                if connect_to_database "$db_name"; then
                    log "INFO" "Successfully connected to database '$db_name'"
                    bash "$DDL_DBMS_DIR_PATH/dml_dbms.sh" "$db_name"
                else
                    log "ERROR" "Failed to connect to database '$db_name'"
                fi
                ;;
            "Exit")
                log "INFO" "User selected Exit, terminating application"
                echo "" > $DDL_DBMS_DIR_PATH/../logs/dbms.log
                exit 0
                ;;
            *)
                log "WARNING" "Invalid option selected: $selected_option"
                continue
                ;;
        esac
    done
}

ddl_main