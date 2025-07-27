
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
    local title="$1"
    shift
    local menu_options=("$@")

    if [[ "$USE_FZF" == true ]]; then
        local preview_cmd="tail -n 50 \"$DML_DBMS_DIR_PATH/../logs/dbms.log\" \
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

function dml_main(){
    
    while true; do
        local options=("Create Table" "Drop Table" "List Tables" "Select Table" "Back")
        
        local selected_option
        selected_option=$(show_menu_with_fzf "DML Operations for '$db_name'" "${options[@]}")
        
        case "$selected_option" in
            "Create Table")
                log "INFO" "Createing Table ...."
                read -p "Enter the table name to create: " table_name
                create_table "$db_name" "$table_name"
                ;;
            "Drop Table")
                log "INFO" "Dropping Table ...."
                read -p "Enter the table name to drop: " table_name
                drop_table "$db_name" "$table_name"
                ;;
            "List Tables")
                list_tables "$db_name"
                ;;
            "Select Table")
                read -p "Enter the table name to select: " table_name
                if name_exists "$DML_DBMS_DIR_PATH/../database/$db_name" "$table_name"; then
                    dml_table "$table_name"
                else
                    log "ERROR" "Table '$table_name' does not exist in database '$db_name'"
                fi
                ;;
            "Back")
                echo "" > $DML_DBMS_DIR_PATH/../logs/dbms.log
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
    
    while true; do
        local options=("Table Info" "Insert" "Filter Mod" "Back")
        
        local selected_option
        selected_option=$(show_menu_with_fzf "Table Operations for '$table_name'" "${options[@]}")
         
        case "$selected_option" in
            "Table Info")
                log "INFO" "Displaying table information for '$table_name'"
                table_info "$db_name" "$table_name"
                ;;
            "Insert")
                log "INFO" "Inserting data into table '$table_name'"
                insert_row "$db_name" "$table_name"
                ;;
            "Filter Mod")
                log "INFO" "Modifying filter for table '$table_name'"
                bash "$DML_DBMS_DIR_PATH/dql_dbms.sh" "$db_name" "$table_name"
                ;;
            "Back")
                echo "" > $DML_DBMS_DIR_PATH/../logs/dbms.log
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