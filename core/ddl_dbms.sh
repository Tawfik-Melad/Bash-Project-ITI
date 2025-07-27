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

    if [[ "$USE_FZF" == true ]]; then
        local preview_cmd="tail -n 50 \"$DDL_DBMS_DIR_PATH/../logs/dbms.log\" \
            | tac \
            | sed -E 's/(\[ERROR\])/\x1b[31m\1\x1b[0m/; s/(\[INFO\])/\x1b[32m\1\x1b[0m/'"

        local selected
        selected=$(printf '%s\n' "${menu_options[@]}" | fzf --header="$title" --height=100% \
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


function ddl_main(){
    
    while true; do
        local options=("Create Database" "Drop Database" "List Databases" "Connect to Database" "Exit")
        
        local selected_option
        selected_option=$(show_menu_with_fzf "DDL Opedfsadfdrations" "${options[@]}")

        
        case "$selected_option" in
            "Create Database")
                log "INFO" "Create Database ...."
                read -p "Enter the database name to create: " db_name
                create_database "$db_name"

                ;;
            "Drop Database")
                log "INFO" "Drop Database ...."
                read -p "Enter the database name to drop: " db_name
                delete_database "$db_name"

                ;;
            "List Databases")
                    local databases
                    databases=$(ls -1 "$DDL_DBMS_DIR_PATH/../database" 2>/dev/null)
                    log_data "$databases"
                    log "INFO" "📂 Available databases: "
                ;;
            "Connect to Database")
                log "INFO" "Connecting to Database ...."
                read -p "Enter the database name to connect: " db_name
                if connect_to_database "$db_name"; then
                    log "INFO" "Successfully connected to database '$db_name'"
                    bash "$DDL_DBMS_DIR_PATH/dml_dbms.sh" "$db_name"
                else
                    log "ERROR" "Failed to connect to database '$db_name'"
                fi
                ;;
            "Exit")
                log "INFO" "Terminating application and exiting"
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