
#!/bin/bash
DML_DBMS_DIR_PATH="$(dirname ${BASH_SOURCE[0]})"

source "$DML_DBMS_DIR_PATH/../lib/validation.sh"
source "$DML_DBMS_DIR_PATH/../lib/log.sh"
source "$DML_DBMS_DIR_PATH/../lib/dml_operations.sh"

db_name="$1"

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

function dml_main(){
    log "INFO" "Entering DML interface for database '$db_name'"
    
    while true; do
        local options=("Create Table" "Drop Table" "List Tables" "Select Table" "Back")
        log "INFO" "Showing DML menu options"
        
        local selected_option
        selected_option=$(show_menu_with_fzf "DML Operations for '$db_name'" "${options[@]}")
        
        case "$selected_option" in
            "Create Table")
                log "INFO" "User selected Create Table operation"
                read -p "Enter the table name to create: " table_name
                create_table "$db_name" "$table_name"
                ;;
            "Drop Table")
                log "INFO" "User selected Drop Table operation"
                read -p "Enter the table name to drop: " table_name
                drop_table "$db_name" "$table_name"
                ;;
            "List Tables")
                log "INFO" "User selected List Tables operation"
                list_tables "$db_name"
                ;;
            "Select Table")
                log "INFO" "User selected Select Table operation"
                read -p "Enter the table name to select: " table_name
                if name_exists "$DML_DBMS_DIR_PATH/../database/$db_name" "$table_name"; then
                    dml_table "$table_name"
                else
                    log "ERROR" "Table '$table_name' does not exist in database '$db_name'"
                fi
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

function dml_table(){
    local table_name="$1"
    log "INFO" "Entering table interface for '$table_name'"
    
    while true; do
        local options=("Table Info" "Insert" "Filter Mod" "Back")
        log "INFO" "Showing table menu options for '$table_name'"
        
        local selected_option
        selected_option=$(show_menu_with_fzf "Table Operations for '$table_name'" "${options[@]}")
         
        case "$selected_option" in
            "Table Info")
                log "INFO" "User selected Table Info operation"
                table_info "$db_name" "$table_name"
                ;;
            "Insert")
                log "INFO" "User selected Insert operation"
                insert_row "$db_name" "$table_name"
                ;;
            "Filter Mod")
                log "INFO" "User selected Filter Mod operation"
                bash "$DML_DBMS_DIR_PATH/dql_dbms.sh" "$db_name" "$table_name"
                ;;
            "Back")
                log "INFO" "User selected Back, returning to DML menu"
                return 0
                ;;
            *)
                log "WARNING" "Invalid option selected: $selected_option"
                continue
                ;;
        esac
    done
}



dml_main