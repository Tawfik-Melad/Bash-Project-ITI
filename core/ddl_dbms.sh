
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
    USE_FZF=false
fi

function show_menu_with_fzf() {
    local title="$1"
    shift
    local menu_options=("$@")
    
    if [[ "$USE_FZF" == true ]]; then
        local selected
        selected=$(printf '%s\n' "${menu_options[@]}" | fzf --header="$title" --height=10 --reverse --border)
        if [[ -n "$selected" ]]; then
            echo "$selected"
        else
            echo ""
        fi
    else
        # Fallback to select
        PS3="Choose an operation: "
        select option in "${menu_options[@]}"; do
            if [[ -n "$option" ]]; then
                echo "$option"
                break
            else
                log "WARNING" "Invalid selection, showing menu again"
                echo "Invalid option, please try again:"
                continue
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
        selected_option=$(show_menu_with_fzf "DDL Operations" "${options[@]}")
        
        if [[ -z "$selected_option" ]]; then
            log "INFO" "User cancelled menu selection"
            continue
        fi
        
        case "$selected_option" in
            "Create Database")
                log "INFO" "User selected Create Database operation"
                read -p "Enter the database name to create: " db_name
                if [[ -n "$db_name" ]]; then
                    create_database "$db_name"
                else
                    log "WARNING" "Empty database name provided"
                fi
                ;;
            "Drop Database")
                log "INFO" "User selected Drop Database operation"
                read -p "Enter the database name to drop: " db_name
                if [[ -n "$db_name" ]]; then
                    delete_database "$db_name"
                else
                    log "WARNING" "Empty database name provided"
                fi
                ;;
            "List Databases")
                log "INFO" "User selected List Databases operation"
                if [ -d "$DDL_DBMS_DIR_PATH/../database" ]; then
                    local databases
                    databases=$(ls -1 "$DDL_DBMS_DIR_PATH/../database" 2>/dev/null)
                    if [[ -n "$databases" ]]; then
                        log "INFO" "Available databases: $databases"
                    else
                        log "INFO" "No databases found"
                    fi
                else
                    log "INFO" "No databases found"
                fi
                ;;
            "Connect to Database")
                log "INFO" "User selected Connect to Database operation"
                read -p "Enter the database name to connect: " db_name
                if [[ -n "$db_name" ]]; then
                    if connect_to_database "$db_name"; then
                        log "INFO" "Successfully connected to database '$db_name'"
                        bash "$DDL_DBMS_DIR_PATH/dml_dbms.sh" "$db_name"
                    else
                        log "ERROR" "Failed to connect to database '$db_name'"
                    fi
                else
                    log "WARNING" "Empty database name provided"
                fi
                ;;
            "Exit")
                log "INFO" "User selected Exit, terminating application"
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